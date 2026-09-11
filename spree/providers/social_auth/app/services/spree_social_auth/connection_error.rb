module SpreeSocialAuth
  # The provider could not be reached, or answered with something that is not a
  # JSON body. Never reported to the shopper as a failed sign-in: nothing was
  # refused, so trying again is the advice.
  class ConnectionError < Error; end
end
