module Spree
  # The one-off convergence with `.custom-extensions/spree_crm`, which ran a
  # membership engine of its own until this gem replaced it (ruled 2026-09-18).
  #
  # Anonymous models over the legacy tables: this gem must run in an application
  # that never installed the CRM, and the CRM's own classes are retired
  # alongside it. Raw columns, so nothing here re-opens core.
  #
  # A CRM plan becomes a tier, and a CRM membership a term. Plan amounts are not
  # carried over — a tier is priced by its SKU's product in the store — and the
  # CRM's own rows are left where they are, because they are the record of what
  # that engine said.
  class CrmMembershipImport
    def call
      unless connection.table_exists?('spree_crm_memberships')
        puts 'spree_crm_memberships is not in this database — nothing to move.'
        return
      end

      ported = port_plans
      moved, skipped = port_memberships

      puts "Ported #{ported} plans onto tiers, and moved #{moved} terms (#{skipped} skipped)."
      puts 'The CRM tables are left as they are: they are the record of what that engine said.'
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    def crm_plans
      @crm_plans ||= Class.new(ActiveRecord::Base) { self.table_name = 'spree_crm_membership_plans' }
    end

    def crm_memberships
      @crm_memberships ||= Class.new(ActiveRecord::Base) { self.table_name = 'spree_crm_memberships' }
    end

    # A CRM plan names a tier this gem had not heard of: its group becomes a
    # tier, and the three things worth keeping — the SKU, the auto-renew flag
    # and the grace window — land on the settings row. A plan with no group
    # names no audience, so it is left alone.
    #
    # @return [Integer] how many groups became tiers
    def port_plans
      ported = 0

      crm_plans.where.not(customer_group_id: nil).order(:id).each do |plan|
        next if Spree::MembershipTierSetting.exists?(customer_group_id: plan.customer_group_id)

        Spree::MembershipTierSetting.create!(
          customer_group_id: plan.customer_group_id,
          rank: plan.id,
          validity_days: plan.billing_period.to_s == 'year' ? 365 : 30,
          auto_renew: plan.auto_renew.present?,
          grace_days: plan.grace_days.to_i,
          sku: plan.sku.presence,
          metadata: { 'migrated_from_crm_membership_plan_id' => plan.id }
        )

        ported += 1
      end

      ported
    end

    # @return [Array<Integer>] how many terms were written, and how many skipped
    def port_memberships
      moved = 0
      skipped = 0

      # The term that ends last is the one the customer actually holds, so it is
      # imported first: a stale live row beside it then skips as a duplicate of
      # a tier it never really held.
      crm_memberships.order(end_date: :desc, id: :desc).each do |row|
        group_id = crm_plans.where(id: row.plan_id).pick(:customer_group_id)

        if group_id.blank? || row.customer_id.blank?
          puts "  skipped #{row.id}: it has no tier to grant."
          skipped += 1
          next
        end

        # Its natural key, so a second run moves nothing twice.
        if Spree::Membership.where(customer_id: row.customer_id, customer_group_id: group_id,
                                   starts_at: row.start_date).exists?
          puts "  skipped #{row.id}: a term for that customer and tier already covers the window."
          skipped += 1
          next
        end

        Spree::Membership.create!(
          store_id: row.store_id,
          customer_id: row.customer_id,
          customer_group_id: group_id,
          # The CRM's statuses carry over one for one, which is why this gem's
          # term declares the same set. A window that already closed is the
          # sweep's to end on its next pass.
          status: row.status,
          starts_at: row.start_date,
          ends_at: row.end_date,
          metadata: { 'migrated_from_crm_membership_id' => row.id },
          created_at: row.created_at,
          updated_at: row.updated_at
        )

        moved += 1
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
        puts "  skipped #{row.id}: #{e.class}"
        skipped += 1
      end

      [moved, skipped]
    end
  end
end

namespace :spree_memberships do
  desc "Moves spree_crm's membership plans and memberships into this gem's tiers and terms"
  task migrate_crm_memberships: :environment do
    Spree::CrmMembershipImport.new.call
  end
end
