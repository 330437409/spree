module Spree
  module MembershipRights
    # Priority on distribution. It grants no object and declares no panel: what
    # it means is the name the operator gives it, and the client's button for it
    # is the shared one.
    class PriorityDistribution < Spree::MembershipRight
    end
  end
end
