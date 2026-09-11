require 'webmock/rspec'

# Nothing in this suite talks to WeChat. The request shapes are proved with
# stubbed responses, so a real request means a spec is reaching somewhere it
# should not, and it should fail loudly rather than quietly depend on a network.
WebMock.disable_net_connect!(allow_localhost: true)
