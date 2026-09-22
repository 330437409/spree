module Spree
  module MembershipRights
    # The tier's own catalogue price: what a member pays where everybody else
    # pays the list price.
    #
    # The price is the tier's own catalogue, not a setting here — this right is
    # what says the tier has one, and the catalogue is what a reader prices
    # from. Declares no member-centre panel: the client's button for it is the
    # shared one.
    class MemberPrice < Spree::MembershipRight
    end
  end
end
