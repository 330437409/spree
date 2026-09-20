module Spree
  # What a share card says, and where it opens.
  #
  # A plain value object rather than a record: nothing about a share is stored —
  # the card is composed from the thing being shared, every time it is asked
  # for (docs/plans/6.1-store-api-miniprogram-gaps.md).
  class Share
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :title, :string
    attribute :subtitle, :string
    attribute :image_url, :string
    # What the client assigns to WeChat's own share API, and decodes with its
    # own grammar — see {Spree::Shares::Compose}.
    attribute :path, :string
    # The QR and the poster are the identity capability's, and are absent until
    # a target can ask it for them (docs/plans/6.1-miniprogram-platform-services.md).
    attribute :scene, :string
    attribute :qrcode_url, :string
    attribute :poster_url, :string
  end
end
