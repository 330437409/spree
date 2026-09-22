namespace :spree_scenario_orders do
  desc 'Closes scenario purchases whose window passed without a settlement'
  task expire: :environment do
    result = Spree::ScenarioOrders::Expire.call
    puts "expired #{result.value} scenario orders"
  end
end
