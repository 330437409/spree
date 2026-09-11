module SpreeSocialAuth
  # The provider answered, and the answer was a refusal. +code+ is the
  # provider's own code, kept so a merchant can look it up.
  class ApiError < Error
    attr_reader :code

    def initialize(message, code: nil)
      @code = code
      super(message)
    end
  end
end
