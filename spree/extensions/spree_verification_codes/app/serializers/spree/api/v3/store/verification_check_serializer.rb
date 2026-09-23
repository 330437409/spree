module Spree
  module Api
    module V3
      module Store
        # What a successful check answers: the number that was proved and how
        # long the proof holds.
        #
        # No id, because a check is an outcome rather than a record, and
        # nothing that could be replayed — the code itself is not in it, and
        # the write that spends it takes the code again rather than a token
        # from here.
        class VerificationCheckSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize phone: :string, verified_at: [:string, nullable: true], expires_at: :string

          attributes :phone

          attribute :verified_at do |code|
            code.verified_at&.iso8601
          end

          attribute :expires_at do |code|
            code.expires_at.iso8601
          end
        end
      end
    end
  end
end
