class AddSiteAttributesToSpreeSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_sellers, :site_svip, :boolean, null: false, default: false
    add_column :spree_sellers, :business_model, :string
  end
end
