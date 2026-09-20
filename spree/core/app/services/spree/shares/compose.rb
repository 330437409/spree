module Spree
  module Shares
    # The one share payload: what a card for the thing the request names says,
    # and the link it opens.
    #
    # One composer for every kind of thing this storefront shares — a product
    # today, an invitation, a coupon or a team later — because the client
    # assigns the path straight to WeChat's share API and decodes it with its
    # own grammar. Four domains composing that grammar separately is what this
    # replaces (docs/plans/6.1-store-api-miniprogram-gaps.md).
    #
    # The target answers the contract: `share_descriptor(context)` returns the
    # words, the picture and the link's own fields. Composing here is where the
    # grammar lives, so a target never writes a path itself.
    class Compose
      prepend Spree::ServiceModule::Base

      # Every shared link lands on the client's entry page, which reads `type`
      # — the page to open — and re-launches into it with the decoded
      # identifiers (static/behaviors/locationLinkBehavior.js:7-13).
      ENTRY_PATH = '/pages/index'

      # @param target [Object] a record answering `share_descriptor`
      # @param context [Hash] what the request carried for the target's own
      #   descriptor to read — a binding to mint, a team to join
      # @return [Spree::ServiceModule::Result] value is a {Spree::Share}, or a
      #   refusal when the target cannot be shared
      def call(target:, context: {})
        return failure(nil, :not_shareable) unless shareable?(target)

        descriptor = target.share_descriptor(context).to_h.symbolize_keys

        success(
          Share.new(
            title: descriptor[:title],
            subtitle: descriptor[:subtitle],
            image_url: descriptor[:image_url],
            path: path_for(descriptor),
            scene: descriptor[:scene],
            qrcode_url: descriptor[:qrcode_url],
            poster_url: descriptor[:poster_url]
          )
        )
      end

      private

      # A model that answers the contract is shareable; one that does not is
      # not, whatever the request called it.
      def shareable?(target)
        target.respond_to?(:share_descriptor)
      end

      # `/pages/index?type=<page>&typeId=<field-value_field-value>`. The
      # identifiers are the target's own names, because the client resolves them
      # against its own type table rather than against our schema.
      def path_for(descriptor)
        type = descriptor[:type]
        identifiers = (descriptor[:identifiers] || {}).compact

        query = [%(type=#{type})]
        query << %(typeId=#{encode(identifiers)}) if identifiers.any?

        "#{ENTRY_PATH}?#{query.join('&')}"
      end

      # The client's grammar written backwards: it splits the value on `_`,
      # turns each `-` into `=`, and joins the parts with `&`
      # (static/behaviors/locationLinkBehavior.js:7-13).
      #
      # Values are percent-escaped first, because this API's own ids carry the
      # grammar's separator — `prod_UkLWZg9DAJ` would otherwise decode as a
      # field called `id-prod` and a field called `UkLWZg9DAJ`. The decoder is
      # untouched: the page reads its query through a URL parser, which is where
      # an escaped value comes back as it was written.
      #
      # @param identifiers [Hash]
      # @return [String]
      def encode(identifiers)
        identifiers.map { |key, value| "#{key}-#{escape(value)}" }.join('_')
      end

      # @param value [Object]
      # @return [String]
      def escape(value)
        value.to_s.
          gsub('%', '%25').
          gsub('_', '%5F').
          gsub('-', '%2D').
          gsub('&', '%26').
          gsub('=', '%3D')
      end
    end
  end
end
