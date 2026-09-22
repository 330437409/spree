module Spree
  module MembershipRights
    # The annual gift — 开卡送酒. What it gives is looked up per tier, which is
    # why the panel it presents in is paged by tier name.
    class GiveGift < Spree::MembershipRight
      # 开卡送酒
      def self.presents_as
        'yearGiftLevelSettingVos'
      end
    end
  end
end
