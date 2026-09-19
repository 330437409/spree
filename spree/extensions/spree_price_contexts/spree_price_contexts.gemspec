# encoding: UTF-8

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name         = 'spree_price_contexts'
  s.version      = Spree.version
  s.authors      = ['Vendo Connect Inc.', 'Vendo Sp. z o.o.']
  s.email        = 'hello@spreecommerce.org'
  s.summary      = 'Price contexts for Spree Commerce storefronts'
  s.description  = 'The contexts a storefront asks a price in — area, on-site promotion and offline — as channels, and the sellers holding an offer for a product'
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
  # The sellers read is a Store API resource, so the API is where the gem's one
  # controller inherits from.
  s.add_dependency 'spree_api', ">= #{s.version}"
end
