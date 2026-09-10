module SpreeWechatPay
  class Gateway < ::Spree::Gateway
    # Payment sessions for WeChat Pay.
    #
    # A WeChat transaction is created under a merchant order number we generate;
    # that number, not WeChat's transaction id, is the session's external id,
    # because it exists from the moment we ask for a transaction and WeChat's
    # only exists once the customer has paid.
    module PaymentSessions
      extend ActiveSupport::Concern

      # WeChat's default when `time_expire` is omitted, which is what this
      # gateway does — the transaction stays payable for seven days (15 for the
      # scenes that allow it) while the customer's launch token does not.
      TRANSACTION_VALIDITY = 7.days
      # `code_url` for Native and `prepay_id` for the WeChat-browser and APP
      # scenes are documented as valid for two hours; H5's URL for five minutes.
      LAUNCH_TOKEN_VALIDITY = 2.hours
      H5_LAUNCH_TOKEN_VALIDITY = 5.minutes
      # WeChat caps `description` at 127 characters.
      DESCRIPTION_LIMIT = 127
      SCENES = MerchantContext::TRANSACTION_PATHS.keys.freeze
      # The scenes this version actually implements. `enabled_scenes` accepts the
      # whole vocabulary so a merchant's configuration survives an upgrade, but
      # enabling one that is not built yet is refused plainly rather than failing
      # somewhere further in, where the cause would be unrecognisable.
      IMPLEMENTED_SCENES = %w[native jsapi mini_program h5 app].freeze
      # Scenes that must name the payer on the order.
      PAYER_IDENTITY_SCENES = %w[jsapi mini_program].freeze

      def payment_session_class
        Spree::PaymentSessions::WechatPay
      end

      # @param order [Spree::Cart, Spree::Order]
      # @param external_data [Hash] `scene` to choose the payment scene, and
      #   whatever that scene needs — `payer_client_ip` today, an authorization
      #   code once JSAPI lands
      # @return [Spree::PaymentSessions::WechatPay]
      def create_payment_session(order:, amount: nil, external_data: {})
        scene = resolve_scene(external_data)
        total = amount.presence || order.total_minus_store_credits
        amount_in_cents = Spree::Money.new(total, currency: order.currency).cents

        if amount_in_cents.zero?
          raise Spree::Core::GatewayError, Spree.t('wechat_pay.errors.zero_amount')
        end

        number = MerchantOrderNumber.generate(order)
        openid = openid_for(scene, external_data)
        response = transaction_for(number).create(
          scene: scene,
          payload: transaction_payload(
            scene: scene,
            number: number,
            order: order,
            amount_in_cents: amount_in_cents,
            payer_client_ip: payer_client_ip(external_data),
            h5_type: h5_type(external_data),
            openid: openid
          )
        )

        payment_session_class.create!(
          owner: order,
          payment_method: self,
          amount: total,
          currency: order.currency,
          status: 'pending',
          external_id: number,
          customer: order.customer,
          expires_at: TRANSACTION_VALIDITY.from_now,
          external_data: session_data(scene, response, openid: openid, redirect_url: redirect_url(external_data))
        )
      end

      # Renews or replaces the transaction behind a session.
      #
      # This is also how a lapsed launch token is refreshed: the storefront asks
      # for the same amount again, and the gateway re-issues under the same
      # merchant order number — WeChat permits that when every parameter is
      # identical — or replaces the transaction when the amount has moved. The
      # storefront has one code path either way.
      #
      # @param payment_session [Spree::PaymentSessions::WechatPay]
      # @return [Spree::PaymentSessions::WechatPay]
      def update_payment_session(payment_session:, amount: nil, external_data: {})
        total = amount.presence || payment_session.amount
        changed = total.to_d != payment_session.amount.to_d
        lapsed = payment_session.payload_expired?

        # Nothing to do: same money, live token. Asking twice must not open a
        # second transaction.
        return payment_session if !changed && !lapsed

        scene = payment_session.scene || resolve_scene(external_data)
        amount_in_cents = Spree::Money.new(total, currency: payment_session.currency).cents
        owner = payment_session.owner

        response = if changed
                     replace_transaction(payment_session, scene, total, amount_in_cents, owner, external_data)
                   else
                     reissue_transaction(payment_session, scene, amount_in_cents, owner, external_data)
                   end

        payment_session.update!(
          amount: total,
          external_data: session_data(scene, response, openid: openid_for(scene, external_data), redirect_url: redirect_url(external_data))
        )
        payment_session
      end

      # Confirms the session against WeChat rather than against what the
      # storefront reports, and settles it accordingly.
      #
      # Does NOT complete the order — `Carts::Complete` owns that.
      #
      # @param payment_session [Spree::PaymentSessions::WechatPay]
      # @return [Spree::PaymentSessions::WechatPay]
      def complete_payment_session(payment_session:, params: {})
        transaction = transaction_for(payment_session.merchant_order_number)
        response = transaction.query

        if Transaction.paid?(response)
          settle_paid_session(payment_session, response)
        elsif Transaction.closed?(response)
          payment_session.cancel if payment_session.can_cancel?
        else
          # Unpaid, and WeChat can still be paid — so it is only a failure once
          # the transaction has been closed and the close has actually succeeded.
          close_then_fail(payment_session, transaction)
        end

        payment_session
      end

      private

      def transaction_for(number)
        Transaction.new(context: merchant_context, client: client, merchant_order_number: number)
      end

      def settle_paid_session(payment_session, response)
        payment_session.process if payment_session.can_process?
        payment_session.record_wechat_response(response)
        payment_session.settle_payment!(captured: true, metadata: payment_metadata(response))
        payment_session.complete unless payment_session.completed?
      end

      def close_then_fail(payment_session, transaction)
        transaction.close
        payment_session.fail if payment_session.can_fail?
      rescue ApiError
        # The close was refused. The usual reason is that the customer paid in
        # the moment between the query and the close, so ask again rather than
        # believing the refusal — this branch settling a payment is the race
        # resolving in the customer's favour, not an error path.
        response = transaction.query
        if Transaction.paid?(response)
          settle_paid_session(payment_session, response)
        else
          raise
        end
      end

      def replace_transaction(payment_session, scene, total, amount_in_cents, owner, external_data)
        cancel_open_transaction(payment_session)
        number = MerchantOrderNumber.generate(owner)
        response = transaction_for(number).create(
          scene: scene,
          payload: transaction_payload(
            scene: scene, number: number, order: owner,
            amount_in_cents: amount_in_cents, payer_client_ip: payer_client_ip(external_data),
            h5_type: h5_type(external_data), openid: openid_for(scene, external_data)
          )
        )
        # The session is the same intent; only the transaction under it moved.
        payment_session.external_id = number
        response
      end

      def reissue_transaction(payment_session, scene, amount_in_cents, owner, external_data)
        transaction_for(payment_session.merchant_order_number).create(
          scene: scene,
          payload: transaction_payload(
            scene: scene, number: payment_session.merchant_order_number, order: owner,
            amount_in_cents: amount_in_cents, payer_client_ip: payer_client_ip(external_data),
            h5_type: h5_type(external_data), openid: openid_for(scene, external_data)
          )
        )
      end

      # Closing is best-effort: a transaction that was never created, or one
      # already paid, has nothing to close and the replacement proceeds anyway.
      def cancel_open_transaction(payment_session)
        transaction_for(payment_session.merchant_order_number).close
      rescue ApiError
        nil
      end

      def resolve_scene(external_data)
        requested = (external_data[:scene].presence || external_data['scene'].presence)&.to_s
        enabled = Array(preferred_enabled_scenes).map(&:to_s).select { |scene| SCENES.include?(scene) }

        if enabled.empty?
          raise Spree::Core::GatewayError, Spree.t('wechat_pay.errors.no_scenes_enabled')
        end

        scene = requested.presence || (enabled.one? ? enabled.first : nil)

        if scene.blank?
          raise Spree::Core::GatewayError, Spree.t('wechat_pay.errors.scene_required')
        end

        # A scene the merchant never switched on is refused rather than
        # substituted: the storefront asked because it could drive that one, and
        # quietly paying by a different route is worse than an error.
        unless enabled.include?(scene)
          raise Spree::Core::GatewayError, Spree.t('wechat_pay.errors.scene_not_enabled', scene: scene)
        end

        unless IMPLEMENTED_SCENES.include?(scene)
          raise Spree::Core::GatewayError, Spree.t('wechat_pay.errors.scene_not_implemented', scene: scene)
        end

        scene
      end

      # Every scene shares this shape; what differs per scene is layered on in
      # the phases that implement them.
      def transaction_payload(scene:, number:, order:, amount_in_cents:, payer_client_ip: nil, openid: nil, h5_type: nil)
        payload = {
          'appid' => merchant_context.app_id_for(scene),
          'mchid' => merchant_context.merchant_id,
          'description' => description_for(order),
          'out_trade_no' => number,
          'notify_url' => webhook_url,
          'amount' => { 'total' => amount_in_cents, 'currency' => 'CNY' }
        }

        # The scenes that know who is paying must name them. A scene that needs
        # an openid and does not get one is refused before the call, because
        # WeChat's own error for it is a bare parameter complaint.
        payload['payer'] = { 'openid' => openid } if openid.present?

        # H5 carries a mandatory scene object — its device type and the customer
        # IP — where the others carry an optional one (the IP alone, when known).
        scene_info = if scene == 'h5'
                       h5_scene_info(payer_client_ip, h5_type)
                     elsif payer_client_ip.present?
                       { 'payer_client_ip' => payer_client_ip }
                     end
        payload['scene_info'] = scene_info if scene_info.present?

        payload
      end

      # The fields H5 requires, refused here rather than handed to WeChat to
      # reject with a bare parameter complaint.
      def h5_scene_info(payer_client_ip, h5_type)
        if h5_type.blank?
          raise Spree::Core::GatewayError, Spree.t('wechat_pay.errors.h5_type_required')
        end
        if payer_client_ip.blank?
          raise Spree::Core::GatewayError, Spree.t('wechat_pay.errors.payer_client_ip_required')
        end

        { 'h5_info' => { 'type' => h5_type }, 'payer_client_ip' => payer_client_ip }
      end

      # What the customer sees on their WeChat bill.
      def description_for(order)
        preferred_statement_descriptor.presence ||
          [store&.name, order.number].compact_blank.join(' ')
            .first(DESCRIPTION_LIMIT)
      end

      def payer_client_ip(external_data)
        external_data[:payer_client_ip].presence || external_data['payer_client_ip'].presence
      end

      def h5_type(external_data)
        external_data[:h5_type].presence || external_data['h5_type'].presence
      end

      def redirect_url(external_data)
        external_data[:redirect_url].presence || external_data['redirect_url'].presence
      end

      # Only what the gateway produced is stored. The caller's own external data
      # is not echoed back: it can carry a single-use authorization code, and the
      # storefront can read this record.
      def session_data(scene, response, openid: nil, redirect_url: nil)
        payload = {
          'scene' => scene,
          'payload_expires_at' => (Time.current + launch_token_validity(scene)).iso8601
        }

        payload['code_url'] = response['code_url'] if response['code_url'].present?
        payload['openid'] = openid if openid.present?
        payload['h5_url'] = h5_url(response, redirect_url) if response['h5_url'].present?

        if response['prepay_id'].present?
          payload['prepay_id'] = response['prepay_id']
          # Only what the storefront needs to start the payment, signed here.
          # Handing over the raw identifier would leave every storefront
          # implementing the signature, and getting it wrong fails silently.
          payload['launch_params'] = LaunchParameters.new(
            signer: merchant_context.signer,
            scene: scene,
            app_id: merchant_context.app_id_for(scene),
            prepay_id: response['prepay_id']
          ).to_h
        end

        payload
      end

      def launch_token_validity(scene)
        scene == 'h5' ? H5_LAUNCH_TOKEN_VALIDITY : LAUNCH_TOKEN_VALIDITY
      end

      # The URL is passed through untouched except for the URL-encoded return
      # address WeChat redirects to once the customer has paid. WeChat forbids
      # altering it in any other way and rejects a modified one.
      def h5_url(response, redirect_url)
        url = response['h5_url']
        return url if redirect_url.blank?

        "#{url}&redirect_url=#{CGI.escape(redirect_url)}"
      end

      # The payer's identity, for the scenes that need one.
      #
      # The authorization code is exchanged here rather than accepted as an
      # openid, because an openid supplied by the browser would be an identity
      # the browser got to choose. The AppSecret also stays here: it is the one
      # credential a storefront must never hold.
      #
      # @return [String, nil] nil for a scene that carries no payer identity
      def openid_for(scene, external_data)
        return nil unless PAYER_IDENTITY_SCENES.include?(scene.to_s)

        code = external_data[:code].presence || external_data['code'].presence
        if code.blank?
          raise Spree::Core::GatewayError,
                Spree.t('wechat_pay.errors.authorization_code_required', scene: scene)
        end

        oauth.openid_for(scene: scene, code: code)
      end

      def oauth
        Oauth.new(context: merchant_context)
      end

    end
  end
end
