module Spree
  module Api
    module V3
      module Store
        class AuthController < Store::BaseController
          include Spree::Api::V3::AuthenticationStrategies
          include Spree::Api::V3::OauthState

          REGISTRATION_TOKEN_PURPOSE = 'spree/store/social_signup'.freeze
          REGISTRATION_TOKEN_EXPIRY = 15.minutes

          allow_guest_storefront_access!
          # Tighter rate limits for auth endpoints (per IP to prevent brute
          # force). Distinct `name:` per declaration — without one, Rails keys
          # every counter in this controller on the same (controller, client)
          # cache entry, silently merging the budgets.
          rate_limit to: Spree::Api::Config[:rate_limit_login], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :create, name: 'login', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_login]) }
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :refresh, name: 'refresh', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :logout, name: 'logout', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :providers, name: 'providers', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }
          rate_limit to: Spree::Api::Config[:rate_limit_login], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :complete, name: 'complete', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_login]) }

          skip_before_action :authenticate_user, only: [:create, :refresh, :logout, :providers, :complete]

          # POST  /api/v3/store/auth/login
          # Supports multiple authentication providers via :provider param.
          #
          #   { "provider": "email", "email": "...", "password": "..." }
          #
          # A provider reached by a browser redirect answers with the
          # authorization code instead of credentials:
          #
          #   { "provider": "wechat", "code": "...", "state": "...", "redirect_uri": "..." }
          #
          # When the provider returned no email, nothing is created: the
          # response carries a registration token and the shopper supplies one
          # through #complete.
          def create
            strategy = authentication_strategy
            return unless strategy # Error already rendered by authentication_strategy
            return render_invalid_oauth_state unless oauth_state_valid?
            return render_redirect_uri_not_allowed unless redirect_uri_allowed?

            result = login_result(strategy)

            return render_registration_required(strategy) if registration_required?(strategy)

            if result.success?
              render json: auth_response(result.value)
            else
              render_error(
                code: ERROR_CODES[:authentication_failed],
                message: result.error,
                status: :unauthorized
              )
            end
          end

          # GET /api/v3/store/auth/providers
          #
          # Drives the storefront's login page: the password form when :email is
          # registered, a button per redirect provider. The authorization URL
          # carries a signed state bound to the provider and this store.
          #
          # Unauthenticated — it is read before anyone can log in — so it
          # exposes only provider keys, kinds, labels, URLs and whether a
          # registration step is coming.
          def providers
            described = Spree.store_authentication_strategies.describe do |key|
              issue_oauth_state(key, store: current_store)
            end

            render json: { providers: described }
          end

          # POST /api/v3/store/auth/complete
          #
          # The second call of a social registration. The provider authenticated
          # the shopper but returned no email, so no account could exist yet;
          # the signed token carries the verified identity and the shopper
          # supplies the address. Registration itself runs through
          # Spree.customer_create_workflow.
          def complete
            payload = registration_token_payload
            return if payload.nil?

            resolution = Spree::Authentication::RegisterAccount.new(
              profile: Spree::Authentication::Profile.from_h(payload),
              store: current_store
            ).call(
              email: params[:email],
              first_name: params[:first_name],
              last_name: params[:last_name],
              terms_of_service: params[:terms_of_service],
              ip_address: request.remote_ip,
              user_agent: request.user_agent&.truncate(255)
            )

            render_registration_result(resolution)
          end

          # POST  /api/v3/store/auth/refresh
          # Accepts: { "refresh_token": "rt_xxx" }
          # Returns new access JWT + rotated refresh token
          def refresh
            refresh_token_value = params[:refresh_token]

            if refresh_token_value.blank?
              return render_error(
                code: ERROR_CODES[:invalid_refresh_token],
                message: 'refresh_token is required',
                status: :unauthorized
              )
            end

            refresh_token = Spree::RefreshToken.active.for_audience(JWT_AUDIENCE_STORE).find_by(token: refresh_token_value)

            if refresh_token.nil?
              return render_error(
                code: ERROR_CODES[:invalid_refresh_token],
                message: 'Invalid or expired refresh token',
                status: :unauthorized
              )
            end

            user = refresh_token.user
            new_refresh_token = refresh_token.rotate!(request_env: request_env_for_token)

            render json: {
              token: generate_jwt(user),
              refresh_token: new_refresh_token.token,
              user: user_serializer.new(user, params: serializer_params).to_h
            }
          end

          # POST  /api/v3/store/auth/logout
          # Accepts: { "refresh_token": "rt_xxx" }
          # Revokes the submitted refresh token. The token itself is the
          # credential — no access JWT is required, so clients with an expired
          # access token can still log out. Narrowed to this surface's own
          # tokens: ending a session belongs to the surface that started it.
          def logout
            refresh_token_value = params[:refresh_token]

            if refresh_token_value.present?
              Spree::RefreshToken.for_audience(JWT_AUDIENCE_STORE).find_by(token: refresh_token_value)&.destroy
            end

            head :no_content
          end

          protected

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              currency: current_currency,
              user: current_user,
              includes: [],
              hide_prices: hide_prices?
            }
          end

          private

          def oauth_state_purpose
            'spree/store/oauth_state'
          end

          def auth_response(user)
            refresh_token = Spree::RefreshToken.create_for(user, audience: JWT_AUDIENCE_STORE, request_env: request_env_for_token)

            {
              token: generate_jwt(user),
              refresh_token: refresh_token.token,
              user: user_serializer.new(user, params: serializer_params).to_h
            }
          end

          def request_env_for_token
            {
              ip_address: request.remote_ip,
              user_agent: request.user_agent&.truncate(255)
            }
          end

          def authentication_strategies
            Spree.store_authentication_strategies
          end

          def authentication_user_class
            Spree.customer_class
          end

          def user_serializer
            Spree.api.customer_serializer
          end

          def login_result(strategy)
            redirect_provider? ? strategy.callback : strategy.authenticate
          end

          # The registry knows how a provider is reached — a configured factory
          # answers for the entry, which a strategy instance cannot.
          def redirect_provider?
            authentication_strategies.redirect?(params[:provider].presence || 'email')
          end

          # The state is checked before anything is exchanged, and it is bound
          # to this store as well as the provider, so a state minted on another
          # store's login page cannot complete here.
          def oauth_state_valid?
            return true unless redirect_provider?

            valid_oauth_state?(store: current_store)
          end

          def render_invalid_oauth_state
            render_error(
              code: ERROR_CODES[:invalid_oauth_state],
              message: 'The sign-in attempt expired. Please start again.',
              status: :bad_request
            )
          end

          # The storefront supplies the redirect URI, and the API relays it to
          # the provider, so it is checked against this store's own origins
          # before any code is exchanged.
          def redirect_uri_allowed?
            return true unless redirect_provider?

            current_store.allowed_origin?(params[:redirect_uri])
          end

          def render_redirect_uri_not_allowed
            render_error(
              code: ERROR_CODES[:redirect_url_not_allowed],
              message: 'redirect_uri must be one of this store\'s allowed origins',
              status: :bad_request
            )
          end

          def registration_required?(strategy)
            strategy.respond_to?(:registration_required?) && strategy.registration_required?
          end

          def render_registration_required(strategy)
            render json: {
              status: 'registration_required',
              registration_token: issue_registration_token(strategy.registration_profile)
            }
          end

          def issue_registration_token(profile)
            # Signed, not encrypted: the client can read this payload, so the
            # provider's tokens never travel in it. The identity is attached
            # without them and picks them up on the next login.
            payload = profile.to_h.except(:tokens).merge(store_id: current_store.id)

            Rails.application.message_verifier(REGISTRATION_TOKEN_PURPOSE).generate(
              payload,
              expires_in: REGISTRATION_TOKEN_EXPIRY
            )
          end

          # A token bound to another store is as useless as a forged one: it
          # would register an account against the wrong shop.
          def registration_token_payload
            payload = Rails.application.message_verifier(REGISTRATION_TOKEN_PURPOSE).verified(params[:registration_token])

            if !payload.is_a?(Hash) || payload['store_id'].to_s != current_store.id.to_s
              render_error(
                code: ERROR_CODES[:invalid_registration_token],
                message: 'The registration token is invalid or has expired',
                status: :unauthorized
              )
              return nil
            end

            payload
          end

          def render_registration_result(resolution)
            case resolution.status
            when 'authenticated'
              render json: auth_response(resolution.user), status: :created
            when 'email_taken'
              render_error(
                code: ERROR_CODES[:email_taken],
                message: Spree.t('errors.messages.email_taken'),
                status: :unprocessable_content
              )
            else
              errors = resolution.record_errors
              return render_validation_error(errors) if errors.present?

              render_error(
                code: ERROR_CODES[:resource_invalid],
                message: resolution.message.presence || 'Registration failed',
                status: :unprocessable_content
              )
            end
          end
        end
      end
    end
  end
end
