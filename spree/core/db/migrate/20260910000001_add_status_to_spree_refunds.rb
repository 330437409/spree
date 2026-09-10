class AddStatusToSpreeRefunds < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_refunds, :status, :string
    add_index :spree_refunds, :status

    # Every refund that predates this column was credited at the gateway before
    # the row was kept — a refund row was only ever created and then either
    # credited or destroyed. Reading them as anything but completed would
    # release balance that has already been paid back, so the backfill states
    # what they already are rather than guessing.
    Spree::Refund.where(status: nil).update_all(status: 'completed', updated_at: Time.current)
  end
end
