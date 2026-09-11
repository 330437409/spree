module SpreeSocialAuth
  # Base for everything this gem raises at a provider. Strategies translate
  # these into a failure message a person can act on.
  class Error < StandardError; end
end
