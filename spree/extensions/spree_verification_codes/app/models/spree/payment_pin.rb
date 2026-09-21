module Spree
  # The customer's payment PIN: the second factor a balance spend asks for.
  #
  # Its own table rather than a column on the customer. A PIN is not profile
  # data: it is a credential with a lockout, a rotation story and an erasure
  # obligation, and its failures are a security event rather than a profile
  # edit (docs/plans/6.1-phone-verification-and-payment-pin.md).
  #
  # `required` is the client's display switch and has nothing to do with
  # whether a PIN exists: a customer may keep one and stop being asked for it.
  # The two are independent in the client and stay independent here.
  class PaymentPin < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata

    acts_as_paranoid

    LENGTH = 6
    # Five wrong guesses, then half an hour. Shaped after Spree::AccountLockout
    # without reusing it — that module is bound to login, and a PIN is guessed
    # at on a page a login lockout never sees.
    MAX_ATTEMPTS = 5
    LOCKOUT_DURATION = 30.minutes

    has_secure_password :pin, validations: false

    belongs_to :customer, class_name: "::#{Spree.customer_class}"

    validates :customer, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }
    validates :required, inclusion: { in: [true, false] }
    validates :pin, format: { with: /\A\d{6}\z/, message: :six_digits }, if: -> { pin.present? }
    validate :pin_is_not_a_guess, if: -> { pin.present? }

    # The two rules the client applies in its own form, repeated where they can
    # be enforced: a run of identical digits or a straight sequence is what a
    # guesser tries first, and a client-side rule is a suggestion.
    def pin_is_not_a_guess
      digits = pin.to_s.chars.map(&:to_i)
      steps = digits.each_cons(2).map { |left, right| right - left }.uniq

      errors.add(:pin, :too_simple) if digits.uniq.one? || steps == [1] || steps == [-1]
    end

    # @return [Boolean]
    def locked?
      locked_until.present? && locked_until > Time.current
    end

    # Checks a PIN the customer typed, and records what that answer means.
    #
    # @param candidate [String, nil]
    # @return [Boolean]
    def verify(candidate)
      # A lockout that has run its course is over: the counter that armed it
      # goes with it, so the next wrong guess re-arms a full window rather
      # than locking on the first try.
      clear_failed_attempts! if locked_until.present? && !locked?

      return false if locked?
      return false unless authenticate_pin(candidate.to_s)

      clear_failed_attempts!
      true
    end

    # Counts a wrong guess and locks the row once the threshold is reached.
    # Serialized with a row lock so concurrent guesses read the latest counter —
    # otherwise a stale in-memory value could cross the threshold without ever
    # being persisted.
    #
    # @return [void]
    def record_failed_attempt!
      with_lock do
        increment(:failed_attempts)
        # Armed once, when the threshold is crossed. Re-arming on every later
        # guess would let a customer tapping retry — or an attacker looping
        # the request — hold the window open forever.
        self.locked_until = LOCKOUT_DURATION.from_now if locked_until.nil? && failed_attempts >= MAX_ATTEMPTS
        save!
      end
    end

    # Skips the row lock and the write when there is nothing to clear, which
    # is the common case on the money path: a customer whose counter is at
    # zero and who is not locked.
    #
    # @return [void]
    def clear_failed_attempts!
      return if failed_attempts.zero? && locked_until.nil?

      with_lock { update!(failed_attempts: 0, locked_until: nil) }
    end
  end
end
