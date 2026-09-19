class IndexDatasetVersionOnSpreeAdministrativeDivisions < ActiveRecord::Migration[8.1]
  def change
    # Every cached tree read resolves the current release first, and a release
    # is a fact of the whole table — so the read that answers "which release is
    # this?" is a maximum over this column, and it should not scan 44,000 rows
    # to find it.
    add_index :spree_administrative_divisions, :dataset_version,
              name: 'index_spree_administrative_divisions_on_dataset_version'
  end
end
