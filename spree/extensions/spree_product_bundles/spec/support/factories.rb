FactoryBot.define do
  factory :product_bundle, class: 'Spree::ProductBundle' do
    store { Spree::Store.default || association(:store) }
    sequence(:title) { |n| "套餐 #{n}" }

    transient do
      # The components, as a hash of variant => quantity, or a list of variants
      # one of each.
      components { {} }
    end

    after(:build) do |bundle, evaluator|
      rows = evaluator.components.is_a?(Hash) ? evaluator.components : evaluator.components.to_h { |v| [v, 1] }
      rows.each { |variant, quantity| bundle.components.build(variant: variant, quantity: quantity) }
    end
  end

  factory :bundle_component, class: 'Spree::BundleComponent' do
    bundle
    variant
    quantity { 1 }
  end
end
