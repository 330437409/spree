module Spree
  module Api
    module V3
      # One tap target over the banner: where it sits, written the way the client
      # lays it out, and what it opens.
      #
      # Deliberately not a `BaseSerializer`: an area is a row of a JSON column
      # rather than a record, so there is no id and there are no timestamps.
      class MembershipBannerAreaSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize area_rem: :string, link: :string, name: 'string | null'

        attribute(:area_rem) { |area| area['area_rem'] }
        attribute(:link) { |area| area['link'] }
        attribute(:name) { |area| area['name'] }
      end
    end
  end
end
