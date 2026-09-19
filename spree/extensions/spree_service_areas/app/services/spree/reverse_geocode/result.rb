module Spree
  module ReverseGeocode
    # What a provider answered, before anything is mapped: the names it knows,
    # the code it knows (if it knows one) and the pair it answered for.
    #
    # Codes stay in the vendor's own terms here — mapping them to the bureau's
    # is the mapper's job — and every field but the pair may be absent, because
    # a point in the middle of nowhere is a legitimate answer.
    class Result
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :latitude, :float
      attribute :longitude, :float
      attribute :provider, :string

      attribute :province_code, :string
      attribute :city_code, :string
      attribute :district_code, :string

      attribute :province_name, :string
      attribute :city_name, :string
      attribute :district_name, :string
      attribute :town_name, :string

      # @return [Boolean] whether the provider knew where this point is at all
      def located?
        province_code.present? || province_name.present?
      end
    end
  end
end
