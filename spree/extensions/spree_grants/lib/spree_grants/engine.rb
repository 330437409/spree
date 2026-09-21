require 'rails/engine'

module SpreeGrants
  # Nothing of this gem registers itself into core: the kinds belong to the
  # plans that own the things owed, and each of them appends its own to
  # `Spree.grant_kinds` in its own engine. Today that list is empty, and the
  # gem is the row's service and the kinds' contract
  # (docs/plans/6.1-grant-and-benefit-primitive.md).
  class Engine < Rails::Engine
    engine_name 'spree_grants'
  end
end
