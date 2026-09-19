module Spree
  module SellerRouting
    # Refuses a service-area polygon that could not be matched against later:
    # fewer than four points, a ring that does not close, a coordinate that is
    # not a finite number or is off the planet, or a ring that crosses itself.
    #
    # Winding is not one of the refusals — {Spree::SellerRouting::Polygon}
    # canonicalises it, and the model writes the canonical form back.
    class PolygonValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        return if value.blank?

        polygon = Polygon.new(value)
        return if polygon.valid?

        polygon.errors.each do |error|
          record.errors.add(attribute, error[:error], **{ value: value }.merge(options))
        end
      end
    end
  end
end
