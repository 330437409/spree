# encoding: UTF-8

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name         = 'spree_memberships'
  s.version      = Spree.version
  s.authors      = ['Vendo Connect Inc.', 'Vendo Sp. z o.o.']
  s.email        = 'hello@spreecommerce.org'
  s.summary      = 'Membership tiers and their rights for Spree Commerce'
  s.description  = 'A tier is a customer group plus one settings row; what it grants are registered rights, and the member centre is a projection of that registry'
  s.homepage     = 'https://spreecommerce.org'
  s.license      = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'spree_core', ">= #{s.version}"
  # Its surface is the Store API's, inheriting the same base controllers.
  s.add_dependency 'spree_api', ">= #{s.version}"
  # A card is bought through a scenario order — nothing ships, so the purchase is
  # the frame that has no cart — and the card records which purchase issued it.
  s.add_dependency 'spree_scenario_purchases', ">= #{s.version}"
end
