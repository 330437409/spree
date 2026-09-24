module Spree
  module Api
    module V3
      # The member centre's banner as its page renders it: the picture, the title
      # beside it, and the tap targets laid over it.
      class MembershipBannerSerializer < BaseSerializer
        typelize name: 'string | null', pic: :string, areas: 'MembershipBannerArea[]'

        attributes :name, :pic
        attribute(:areas) do |banner|
          banner.areas.map do |area|
            Spree::Api::V3::MembershipBannerAreaSerializer.new(area, params: params).to_h
          end
        end
      end
    end
  end
end
