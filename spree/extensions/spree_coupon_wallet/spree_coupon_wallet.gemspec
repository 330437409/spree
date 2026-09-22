# encoding: UTF-8

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name         = 'spree_coupon_wallet'
  s.version      = Spree.version
  s.authors      = ['Vendo Connect Inc.', 'Vendo Sp. z o.o.']
  s.email        = 'hello@spreecommerce.org'
  s.summary      = 'A coupon wallet for Spree Commerce'
  s.description  = 'The coupons a customer holds, the campaigns that hand them out, and the reads the mini program draws its wallet with'
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
  # A holding is a kind of the shared grant row, which this gem writes through
  # and does not own.
  s.add_dependency 'spree_grants', ">= #{s.version}"
end
