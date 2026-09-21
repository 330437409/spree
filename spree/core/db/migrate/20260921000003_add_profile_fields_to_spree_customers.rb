class AddProfileFieldsToSpreeCustomers < ActiveRecord::Migration[8.1]
  def change
    # The storefront profile the customer edits — a nickname, how they
    # describe themselves, a birthday for the campaign that wishes them, and
    # the city they usually buy from. Columns rather than metadata because
    # these are read on every app boot and will be segmented on (a birthday
    # campaign wants an index, not a JSON scan)
    # (docs/plans/6.1-store-api-miniprogram-gaps.md).
    #
    # The avatar needs no column: a customer already has one as an ActiveStorage
    # attachment.
    add_column :spree_customers, :nickname, :string
    add_column :spree_customers, :gender, :string
    add_column :spree_customers, :birthday, :date
    add_column :spree_customers, :city, :string
  end
end
