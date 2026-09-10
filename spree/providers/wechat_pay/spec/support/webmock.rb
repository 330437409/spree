require 'webmock/rspec'

# Nothing in this suite talks to WeChat. Signing and verification are proved
# with a locally generated key pair, encryption round-trips through the same
# OpenSSL the production path uses, and the HTTP layer is exercised through
# Faraday's test adapter. A real request means a spec is reaching somewhere it
# should not, and it should fail loudly rather than quietly depend on a network.
WebMock.disable_net_connect!(allow_localhost: true)
