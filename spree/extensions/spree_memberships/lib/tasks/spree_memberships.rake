namespace :spree_memberships do
  desc "Moves spree_crm's membership plans and memberships into this gem's tiers and terms"
  task migrate_crm_memberships: :environment do
    Spree::CrmMembershipImport.new.call
  end
end
