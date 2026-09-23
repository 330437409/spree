# Same reason as the membership rights' column, and the same fix: a preference is
# a YAML-serialized `text` column (`Spree::Preferences::Preferable`), not JSON.
# A campaign's `limit_per_customer` and `valid_for_days` were stored and never
# read back — the campaign behaved as if the operator had left them at their
# defaults, whatever they typed.
class FixCouponCampaignsPreferencesColumn < ActiveRecord::Migration[8.1]
  def up
    change_preferences_to_text
  end

  def down
    change_preferences_to_json
  end

  private

  def change_preferences_to_text
    if connection.adapter_name.match?(/postgres/i)
      execute <<~SQL.squish
        ALTER TABLE spree_coupon_campaigns
        ALTER COLUMN preferences TYPE text USING preferences::text
      SQL
    else
      change_column :spree_coupon_campaigns, :preferences, :text
    end
  end

  def change_preferences_to_json
    if connection.adapter_name.match?(/postgres/i)
      execute <<~SQL.squish
        ALTER TABLE spree_coupon_campaigns
        ALTER COLUMN preferences TYPE jsonb USING preferences::jsonb
      SQL
    else
      change_column :spree_coupon_campaigns, :preferences, :json
    end
  end
end
