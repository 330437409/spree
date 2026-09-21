module Spree
  # A code sent to a phone number, and the proof it stands for.
  #
  # Three of the four states a reader wants — pending, verified, consumed — are
  # stamped timestamps and the fourth, expired, is `expires_at` in the past,
  # which needs no job to write. A status column would be a second source of
  # truth for facts the row already carries
  # (docs/plans/6.1-phone-verification-and-payment-pin.md).
  #
  # The code itself is a BCrypt digest: a six-digit space is a million values,
  # and a bare digest of one is reversible in seconds where BCrypt costs about
  # a tenth of a second per guess — the right trade for a value with a
  # five-minute life and a five-attempt cap.
  class VerificationCode < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata

    acts_as_paranoid

    # The two families the client's own routes separate: every account flow
    # sends from one endpoint and the PIN from another. No finer, because the
    # client verifies with one endpoint that cannot say which flow it is in — a
    # distinction the server cannot enforce is worse than none.
    PURPOSES = %w[account payment].freeze
    # Voice is the fallback the client offers ten seconds in: it exists so a
    # customer whose message never arrives has a second way, not so it can be
    # asked for first.
    CHANNELS = %w[sms voice].freeze

    has_secure_password :code, validations: false

    validates :phone, presence: true
    validates :purpose, inclusion: { in: PURPOSES }
    validates :channel, inclusion: { in: CHANNELS }

    scope :recent_first, -> { order(created_at: :desc) }

    # Digits only, without the country code: a stored "+86 138 0013 8000" and a
    # typed "13800138000" are one number, and a code is keyed by the number
    # rather than by whoever holds it.
    #
    # @param value [String, nil]
    # @return [String]
    def self.normalize_phone(value)
      digits = value.to_s.gsub(/\D/, '')
      digits.sub(/\A86(?=1\d{10}\z)/, '')
    end

    # The code this number and purpose may still be proved with.
    #
    # Only the newest one counts: asking for another code replaces the one
    # before it, so a customer who taps twice cannot leave two live codes
    # behind and a guessed-at older code is not a second way in.
    #
    # @param phone [String]
    # @param purpose [String] one of {PURPOSES}
    # @return [Spree::VerificationCode, nil]
    def self.usable_for(phone:, purpose:)
      record = where(phone: normalize_phone(phone), purpose: purpose, consumed_at: nil).recent_first.first

      record if record&.usable?
    end

    # Spends the code the caller proved. Called inside the transaction of the
    # write that needed it, so however many times a code passes the check it
    # can be spent exactly once.
    #
    # @param phone [String]
    # @param purpose [String]
    # @param code [String] what the caller typed
    # @return [Spree::VerificationCode, nil] the code it spent, or nil when
    #   there was nothing to spend
    def self.consume(phone:, purpose:, code:)
      record = usable_for(phone: phone, purpose: purpose)
      return nil if record.nil?
      return nil unless record.check!(code)

      record.update!(consumed_at: Time.current)
      record
    end

    # Verifies what the caller typed and records what that answer means: a
    # match stamps `verified_at`, anything else spends one of the code's
    # attempts. Deliberately non-consuming — the client posts the same code
    # again to the write that needs it.
    #
    # @param candidate [String]
    # @return [Boolean]
    def check!(candidate)
      if authenticate_code(candidate.to_s)
        update!(verified_at: Time.current)
        true
      else
        increment!(:attempts)
        false
      end
    end

    # @return [Boolean] within its window and with attempts left
    def usable?
      !expired? && attempts < max_attempts
    end

    # @return [Boolean]
    def expired?
      expires_at <= Time.current
    end

    # How many wrong guesses a code survives before it is spent. The store's
    # own number rather than a constant, because the client sets none and a
    # merchant's risk appetite is theirs.
    #
    # @return [Integer]
    def max_attempts
      store.preferred_verification_code_max_attempts
    end
  end
end
