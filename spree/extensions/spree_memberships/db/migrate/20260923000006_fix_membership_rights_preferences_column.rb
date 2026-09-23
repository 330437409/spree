# `Spree::Preferences::Preferable` stores a preference by serializing the column
# as YAML — `serialize :preferences, type: Hash, coder: YAML` — and every core
# table that carries one therefore declares it as `text`. This table was created
# with a JSON column, so the reader found a hash where it expected YAML: an
# operator's settings for a right were stored and never read back, silently
# falling back to each kind's default.
#
# The type is the fix, and the values need no rewriting: a JSON object is valid
# YAML, so the ones already written read back as what they are.
class FixMembershipRightsPreferencesColumn < ActiveRecord::Migration[8.1]
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
        ALTER TABLE spree_membership_rights
        ALTER COLUMN preferences TYPE text USING preferences::text
      SQL
    else
      change_column :spree_membership_rights, :preferences, :text
    end
  end

  def change_preferences_to_json
    if connection.adapter_name.match?(/postgres/i)
      execute <<~SQL.squish
        ALTER TABLE spree_membership_rights
        ALTER COLUMN preferences TYPE jsonb USING preferences::jsonb
      SQL
    else
      change_column :spree_membership_rights, :preferences, :json
    end
  end
end
