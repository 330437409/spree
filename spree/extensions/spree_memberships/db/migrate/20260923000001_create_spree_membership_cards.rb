class CreateSpreeMembershipCards < ActiveRecord::Migration[8.1]
  def change
    # A card is bought, held, given away, claimed and voided before anybody is
    # entitled to anything; a membership is a period a named customer holds.
    # Two rows because they answer different questions, and a customer may hold
    # several dormant cards at once, which one term per customer per tier
    # forbids (docs/plans/6.1-membership-tiers-and-rights.md).
    create_table :spree_membership_cards do |t|
      t.references :store, null: false
      # The buyer, and it does not move when the card is claimed: a card given
      # away stays in the giver's record as 已赠送.
      t.references :customer, null: false
      t.references :customer_group, null: false
      # The purchase that produced it, nil for a card an operator granted.
      t.references :scenario_order
      # The term it started, once it is activated.
      t.references :membership
      t.string :source, null: false
      t.string :status, null: false
      t.boolean :giftable, null: false, default: true
      # Nothing may activate a card past this instant; the client shows it as
      # the deadline to activate or give away.
      t.datetime :activates_before
      t.datetime :activated_at
      t.references :activated_by_customer

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_membership_cards, [:store_id, :status]
    add_index :spree_membership_cards, [:customer_id, :status]

    # One card per purchase. The scenario settlement can retry, and the unique
    # index is what makes the retry find the card it already issued.
    if connection.supports_partial_index?
      add_index :spree_membership_cards, :scenario_order_id, unique: true,
                    where: 'scenario_order_id IS NOT NULL',
                    name: 'index_membership_cards_on_scenario_order'
    else
      # MySQL and MariaDB have no partial index, and they treat every NULL as
      # distinct from every other — so the granted cards sit alongside each
      # other freely while a purchase stays unrepeatable.
      add_index :spree_membership_cards, :scenario_order_id, unique: true,
                    name: 'index_membership_cards_on_scenario_order'
    end

    # A period a named customer holds: the term. NO seller column and no card
    # pointer — the card carries the link, and a column pointing back at it is
    # a cycle in which the two ends can disagree.
    create_table :spree_memberships do |t|
      t.references :store, null: false
      t.references :customer, null: false
      t.references :customer_group, null: false
      t.string :status, null: false
      t.datetime :starts_at
      # An absolute instant the client renders verbatim, so shortening or
      # voiding a term needs no client change.
      t.datetime :ends_at

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_memberships, [:store_id, :status]
    add_index :spree_memberships, [:customer_id, :status]
    add_index :spree_memberships, [:status, :ends_at]

    # One live term per customer per tier: a customer on two tiers is priced by
    # whichever catalogue sits lower, silently. Ended terms are history and stay.
    add_live_term_uniqueness_index
  end

  private

  def add_live_term_uniqueness_index
    if connection.supports_partial_index?
      add_index :spree_memberships, [:customer_id, :customer_group_id], unique: true,
                    where: "status IN ('pending', 'active', 'past_due')",
                    name: 'index_memberships_on_customer_group_live'
    else
      # A stored generated column is the one spelling MySQL and MariaDB both
      # accept: null for anything that is not a live term, and null is what a
      # unique index treats as distinct from every other null. Same shape as
      # the earning key on core's seller transfers.
      execute <<~SQL.squish
        ALTER TABLE spree_memberships
        ADD COLUMN live_key VARCHAR(255)
        AS (CASE WHEN status IN ('pending', 'active', 'past_due')
                 THEN CONCAT(customer_id, '-', customer_group_id) ELSE NULL END) STORED
      SQL

      add_index :spree_memberships, :live_key, unique: true,
                    name: 'index_memberships_on_customer_group_live'
    end
  end
end
