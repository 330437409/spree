# encoding: UTF-8

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name         = 'spree_service_areas'
  s.version      = Spree.version
  s.authors      = ['Vendo Connect Inc.', 'Vendo Sp. z o.o.']
  s.email        = 'hello@spreecommerce.org'
  s.summary      = 'Service areas and seller routing for Spree Commerce'
  s.description  = 'Which seller serves a coordinate: warehouse service-area bindings, reverse geocoding and the routing decision'
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

  s.add_dependency 'faraday'
  s.add_dependency 'spree_core', ">= #{s.version}"
  # The tree is what a vendor code is mapped to and what a binding names, so
  # this gem is only half of itself without it.
  s.add_dependency 'spree_administrative_divisions', ">= #{s.version}"
end
