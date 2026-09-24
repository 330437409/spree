module Spree
  module Api
    module V3
      # The member centre's banner as its page renders it: the picture, the title
      # beside it, and the tap targets laid over it.
      class MembershipBannerSerializer < BaseSerializer
        typelize name: 'string | null', pic: :string, areas: 'MembershipBannerArea[]'

        attributes :name, :pic
        # Only placeable rows are rendered: what the column holds is the
        # operator's, and a row that is not a target at all — one written past
        # the model — is left out rather than answered as nonsense.
        attribute(:areas) do |banner|
          next [] unless banner.areas.is_a?(Array)

          banner.areas.select { |area| area.is_a?(Hash) }.map do |area|
            Spree::Api::V3::MembershipBannerAreaSerializer.new(area, params: params).to_h
          end
        end
      end
    end
  end
end
