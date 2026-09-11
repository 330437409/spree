require 'faraday'
require 'spree_core'
require 'spree_social_auth/engine'

# Social login providers for Spree.
#
# A provider is three small pieces: a per-store `Integration` holding its
# credentials, a `Strategy` that turns an authorization code into a
# `Spree::Authentication::Profile`, and a registry entry (`Provider`) that
# tells the login page whether this store has the provider configured. The
# account rules themselves — who gets signed in, who gets merged, who still
# needs an email — stay in core
# (see docs/plans/6.0-social-login.md).
module SpreeSocialAuth
end
