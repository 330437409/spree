module Spree
  module Api
    module V3
      module Store
        # What a share card says, and where it opens.
        #
        # A card is composed rather than stored, so it carries no id: a plain
        # Alba resource is the right base here.
        class ShareSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize title: [:string, nullable: true],
                   subtitle: [:string, nullable: true],
                   image_url: [:string, nullable: true],
                   path: :string,
                   scene: [:string, nullable: true],
                   qrcode_url: [:string, nullable: true],
                   poster_url: [:string, nullable: true]

          attributes :title, :subtitle, :image_url, :path, :scene, :qrcode_url, :poster_url
        end
      end
    end
  end
end
