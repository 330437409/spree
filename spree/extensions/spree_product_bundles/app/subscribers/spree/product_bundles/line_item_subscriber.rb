module Spree
  module ProductBundles
    # A bundle reaches a cart as its components: the client writes one line per
    # component and names the bundle in the line's own metadata, which is where
    # the group comes from. There is no second add path — the ordinary cart
    # write carries the whole set, and what it means is read off it here.
    #
    # Synchronous, because the cart a client reads back has to show the set it
    # just added: the grouping and the saving are both part of that answer.
    class LineItemSubscriber < Spree::Subscriber
      subscribes_to 'line_item.created', 'line_item.updated', 'line_item.destroyed', async: false

      on 'line_item.created', :group
      on 'line_item.updated', :group
      on 'line_item.destroyed', :ungroup

      # The tag a line carries when it is part of a set.
      BUNDLE_TAG = 'bundle_id'.freeze

      # @param event [Spree::Event]
      def group(event)
        line_item = Spree::LineItem.find_by_prefix_id(event.payload['id'])
        return if line_item.nil?

        write_group_row(line_item)
        recompute(line_item.owner)
      end

      # A line item is hard-deleted, so its own row is gone by now: the group's
      # rows are the only record of which cart it belonged to, and that is why
      # they carry their owner.
      #
      # @param event [Spree::Event]
      def ungroup(event)
        line_item_id = Spree::LineItem.decode_own_prefixed_id(event.payload['id'])
        return if line_item_id.nil?

        rows = Spree::BundleLineItem.where(line_item_id: line_item_id).to_a
        owner = rows.first&.owner
        rows.each(&:destroy!)

        recompute(owner)
      end

      private

      # Grouping is written from the line itself rather than from the payload:
      # the tag is the line's metadata, and the bundle has to be one this store
      # still sells in this variant.
      def write_group_row(line_item)
        bundle_id = line_item.metadata&.fetch(BUNDLE_TAG, nil)
        return if bundle_id.blank?

        bundle = bundle_for(line_item, bundle_id)
        return if bundle.nil?

        row = Spree::BundleLineItem.find_or_initialize_by(line_item_id: line_item.id)
        row.assign_attributes(bundle: bundle, owner: line_item.owner)
        row.save!
      end

      # @return [Spree::ProductBundle, nil]
      def bundle_for(line_item, bundle_id)
        bundle = Spree::ProductBundle.for_store(line_item.store).available.find_by_prefix_id(bundle_id)
        return nil if bundle.nil?
        return nil unless bundle.variants.exists?(id: line_item.variant_id)

        bundle
      end

      # Only a cart or order that already holds a set pays for this: every other
      # line write in the store answers one query and stops.
      def recompute(owner)
        return if owner.nil?
        return unless Spree::BundleLineItem.exists?(owner: owner)

        Spree::ProductBundles::ApplySaving.call(order: owner)
      end
    end
  end
end
