require 'spec_helper'

RSpec.describe Spree::CrmMembershipImport do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:customer) { create(:customer) }

  # Read and written through the tables themselves, the way the import does: the
  # CRM is not installed here, which is the case this has to work in.
  let(:crm_plans) { Class.new(ActiveRecord::Base) { self.table_name = 'spree_crm_membership_plans' } }
  let(:crm_memberships) { Class.new(ActiveRecord::Base) { self.table_name = 'spree_crm_memberships' } }

  # The CRM's tables are not in this gem's dummy — it must run in an application
  # that never installed that engine — so the spec brings its own, in the shape
  # its migrations left them.
  before do
    connection = ActiveRecord::Base.connection
    connection.create_table(:spree_crm_membership_plans, force: true) do |t|
      t.references :store
      t.references :customer_group
      t.string :name
      t.string :billing_period
      t.string :sku
      t.boolean :auto_renew, default: false
      t.integer :grace_days, default: 0
      t.timestamps
    end
    connection.create_table(:spree_crm_memberships, force: true) do |t|
      t.references :store
      t.references :customer
      t.references :plan
      t.date :start_date
      t.date :end_date
      t.string :status
      t.timestamps
    end
  end

  after do
    ActiveRecord::Base.connection.drop_table(:spree_crm_memberships, if_exists: true)
    ActiveRecord::Base.connection.drop_table(:spree_crm_membership_plans, if_exists: true)
  end

  def plan(attributes = {})
    crm_plans.create!({ store_id: store.id, customer_group_id: group.id, name: 'Gold',
                        billing_period: 'month' }.merge(attributes))
  end

  def membership(plan_record, attributes = {})
    crm_memberships.create!({ store_id: store.id, customer_id: customer.id, plan_id: plan_record.id,
                              status: 'active', start_date: Date.current,
                              end_date: 1.month.from_now.to_date }.merge(attributes))
  end

  it 'turns a plan’s group into a tier, keeping the three pieces worth keeping' do
    plan(sku: 'MEM-GOLD', auto_renew: true, grace_days: 7, billing_period: 'year')

    described_class.new.call

    tier = Spree::MembershipTierSetting.find_by(customer_group_id: group.id)
    expect(tier).to be_present
    expect(tier.sku).to eq('MEM-GOLD')
    expect(tier.auto_renew).to be(true)
    expect(tier.grace_days).to eq(7)
    expect(tier.validity_days).to eq(365)
  end

  it 'turns a membership into a term' do
    membership(plan)

    described_class.new.call

    term = Spree::Membership.find_by(customer_id: customer.id)
    expect(term.customer_group_id).to eq(group.id)
    expect(term.status).to eq('active')
    expect(term.metadata['migrated_from_crm_membership_id']).to be_present
  end

  it 'brings a lapsed row across as history' do
    membership(plan, status: 'expired', start_date: 6.months.ago.to_date, end_date: 5.months.ago.to_date)

    described_class.new.call

    expect(Spree::Membership.order(:id).last).to be_expired
  end

  # The old engine could leave two live rows for one customer and tier, which the
  # ladder's own index refuses: the row that ends last is the one they hold.
  it 'keeps the row a customer actually holds when two live rows claim one tier' do
    plan_record = plan
    membership(plan_record, start_date: 6.months.ago.to_date, end_date: 5.months.ago.to_date)
    membership(plan_record, start_date: 1.week.ago.to_date, end_date: 1.month.from_now.to_date)

    described_class.new.call

    expect(Spree::Membership.count).to eq(1)
    expect(Spree::Membership.live.first.ends_at.to_date).to eq(1.month.from_now.to_date)
  end

  it 'leaves a plan with no group alone, and its memberships unmoved' do
    orphan = plan(customer_group_id: nil)
    membership(orphan)

    described_class.new.call

    expect(Spree::MembershipTierSetting.count).to eq(0)
    expect(Spree::Membership.count).to eq(0)
  end

  # A second run finds its own work rather than writing it twice.
  it 'moves nothing twice' do
    membership(plan)

    described_class.new.call
    expect { described_class.new.call }.not_to change { Spree::Membership.count }
  end

  it 'does nothing when the engine was never installed' do
    ActiveRecord::Base.connection.drop_table(:spree_crm_memberships, if_exists: true)
    ActiveRecord::Base.connection.drop_table(:spree_crm_membership_plans, if_exists: true)

    expect { described_class.new.call }.not_to raise_error
  end
end
