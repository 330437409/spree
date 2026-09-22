module Spree
  module MembershipRights
    # A red packet, for the member and for a friend they send it to.
    class SurpriseRedEnvelope < Spree::MembershipRight
      # 惊喜红包
      def self.presents_as
        'rightsLevelSurpriseVoVos'
      end
    end
  end
end
