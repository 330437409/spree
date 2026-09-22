class AddScenarioOrderToPaymentRows < ActiveRecord::Migration[8.1]
  # A purchase that is not an order — a scenario purchase — is paid through the
  # ordinary session flow, and both the session and the payment it settles are
  # owned by what they are for. Core's own two shapes are untouched: nothing is
  # set on the rows that already exist
  # (docs/plans/6.1-scenario-purchases.md).
  def change
    add_reference :spree_payment_sessions, :scenario_order, null: true, index: true
    add_reference :spree_payments, :scenario_order, null: true, index: true
  end
end
