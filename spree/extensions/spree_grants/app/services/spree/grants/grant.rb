module Spree
  module Grants
    # Records that something is owed, once.
    #
    # See {Spree::Grants.grant!} for the keywords.
    #
    # Named for what it does, which puts a service of the same word beside the
    # row it writes: here `Grant` is this class, and the row is always spelled
    # out as `Spree::Grant`.
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
        return answer_for(existing, customer) if existing

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

        # The insert runs in its own savepoint, so a key taken between the
        # lookup and the insert cannot leave a caller's surrounding transaction
        # aborted on PostgreSQL — the retry this key exists for arrives while a
        # workflow holds its own transaction often enough to matter, and an
        # aborted transaction refuses every statement after it, the lookup
        # below included.
        saved = begin
          Spree::Grant.transaction(requires_new: true) { record.save }
        rescue ActiveRecord::RecordNotUnique
          # The key was taken between the lookup and the insert — another job
          # on the same debt, or a request somebody submitted twice. The answer
          # is the row that won, which is what the caller would have got a
          # moment earlier.
          existing = find_existing(store: store, kind: kind, key: key)
          return existing ? answer_for(existing, customer) : failure(record, :already_recorded)
        end

        saved ? success(record) : failure(record, record.errors)
      end

      private

      # The answer a key somebody already holds gets. The key is the whole
      # identity of a debt, so a row removed from the table is not a debt to
      # hand back, and a key already spent on another customer is a key this
      # kind built too loosely.
      #
      # @param existing [Spree::Grant]
      # @param customer [Object, nil]
      # @return [Spree::ServiceModule::Result]
      def answer_for(existing, customer)
        return failure(existing, :already_recorded) if existing.deleted?

        if customer.present? && existing.customer_id.present? && existing.customer_id != customer.id
          return failure(existing, :key_belongs_to_another_customer)
        end

        success(existing)
      end

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
