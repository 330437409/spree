module Spree
  # What a payment — and the session that settles it — is for.
  #
  # A checkout's cart, a completed order and a grouped checkout's group are
  # core's own shapes. A purchase that is none of them registers itself here,
  # so core names no class it does not own and a deployment without that
  # extension resolves no association for one
  # (docs/plans/6.1-scenario-purchases.md).
  module HasPaymentOwner
    extend ActiveSupport::Concern

    included do
      class_attribute :owner_associations, instance_accessor: false, default: []
    end

    class_methods do
      # Declares the association and adds it to the list the owner is read
      # through. The class is named by convention — `:scenario_order` answers
      # `Spree::ScenarioOrder` — because a registration naming its own class as
      # well would be two facts to keep in step.
      #
      # @param name [Symbol]
      # @return [void]
      def register_owner_association(name)
        return if owner_associations.include?(name)

        self.owner_associations += [name]
        belongs_to name, class_name: "Spree::#{name.to_s.camelize}", optional: true
      end

      # @return [Class] the class a registered shape answers
      def owner_class_for(name)
        "Spree::#{name.to_s.camelize}".constantize
      end
    end

    # Whatever this is for, in the order the model lists its shapes: an order
    # before the cart it was built from, core's own before a registered one.
    #
    # @return [Object, nil]
    def owner
      self.class.owner_associations.filter_map { |association| public_send(association) }.first
    end

    # Assigns the owner and clears the shapes it is not.
    #
    # @param record [Object, nil]
    # @return [void]
    # @raise [ArgumentError] when the record may not own this at all
    def owner=(record)
      name = self.class.owner_associations.find do |association|
        record.is_a?(self.class.owner_class_for(association))
      end

      if record.present? && name.nil?
        raise ArgumentError, "#{record.class} does not own a #{self.class.name}"
      end

      self.class.owner_associations.each do |association|
        public_send(:"#{association}=", association == name ? record : nil)
      end
    end
  end
end
