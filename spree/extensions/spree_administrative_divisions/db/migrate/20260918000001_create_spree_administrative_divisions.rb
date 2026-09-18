class CreateSpreeAdministrativeDivisions < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_administrative_divisions do |t|
      t.bigint   :parent_id                    # nil on the 全国 root
      t.string   :level, null: false           # country / province / city / district / township
      t.integer  :depth, null: false           # 0..4, denormalised for deepest-match ordering
      t.string   :code, null: false            # GB/T 2260 (6 digits), the bureau's township code (9), CN for the root
      t.string   :name, null: false
      t.string   :first_pinyin, null: false    # the picker's sort key and A–Z anchor
      t.string   :pinyin                       # full romanisation, for keyword search
      t.string   :dataset_version, null: false # immutable release id, e.g. nbs-2026-09-01
      t.string   :source, null: false          # provenance, e.g. nbs-2026
      t.datetime :source_updated_at
      t.timestamps
    end

    add_index :spree_administrative_divisions, :code, unique: true
    add_index :spree_administrative_divisions, :parent_id
    add_index :spree_administrative_divisions, :depth
  end
end
