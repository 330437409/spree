module Spree
  module MembershipRights
    # Member day: a calendar day the tier's members buy on better terms. The day
    # is the occasion's own period rather than a setting here, which is why this
    # kind declares none.
    class SvipDate < Spree::MembershipRight
      # 会员日
      def self.presents_as
        'userVipDayPageVo'
      end
    end
  end
end
