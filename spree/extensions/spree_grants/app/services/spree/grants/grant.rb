module Spree
  module Grants
    # Records that something is owed, once.
    #
    # See {Spree::Grants.grant!} for the keywords.
    class Grant
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the grant
      def call(kind:, customer: nil, source: nil, idempotency_key: nil, context: nil,
               expires_at: nil, issued: nil, granted_at: nil, metadata: nil, store: nil)
        kind = resolve_kind(kind)
        # Resolved here rather than left to the record's own `ensure_store`: the
        # key is looked up before anything is built, and the lookup needs the
        # store the row will carry.
        store ||= Spree::Current.store

        key = idempotency_key.presence || kind.idempotency_key_for(context)
        return failure(nil, :key_missing) if key.blank?

        existing = find_existing(store: store, kind: kind, key: key)
        return success(existing) if existing

        record = Spree::Grant.new(
          store: store,
          customer: customer,
          kind: kind.api_type,
          status: 'granted',
          idempotency_key: key,
          source: source,
          issued: issued,
          granted_at: granted_at || Time.current,
          expires_at: expires_at,
          metadata: metadata || {}
        )

        record.save ? success(record) : failure(record, record.errors)
      end

      private

      # @param kind [Class, String] the registered kind, or its `api_type`
      # @return [Class]
      def resolve_kind(kind)
        api_type = kind.respond_to?(:api_type) ? kind.api_type : kind.to_s

        Spree::Grant.find_by_api_type(api_type) ||
          raise(UnknownKind, "#{api_type.inspect} is not a registered grant kind")
      end

      # Across deleted rows, because the key means the debt was already
      # recorded: a row removed by cleanup does not hand its key back.
      #
      # @return [Spree::Grant, nil]
      def find_existing(store:, kind:, key:)
        Spree::Grant.with_deleted.find_by(store: store, kind: kind.api_type, idempotency_key: key)
      end
    end
  end
end
