module Spree
  module Api
    module V3
      module Admin
        # The admin twin of the store's promotion-candidate serializer: the
        # admin branch ships one for every store serializer its types reference,
        # because an admin serializer that nests a store one would otherwise
        # emit a type this package does not have (see the seller branch's note
        # in config/initializers/typelizer.rb).
        #
        # It adds nothing: a candidate is the engine's verdict for a line, and
        # there is no guest gating and no admin-only field about it.
        class PromotionCandidateSerializer < V3::PromotionCandidateSerializer
        end
      end
    end
  end
end
