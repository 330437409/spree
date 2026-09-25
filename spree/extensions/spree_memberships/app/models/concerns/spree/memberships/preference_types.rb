module Spree
  module Memberships
    # A preference written wholesale — which is how the admin API delivers them,
    # one `preferences` field permitted as a nested hash and assigned at once —
    # goes past the typecast a preference's own writer does, so a value of the
    # wrong shape reaches the column. The reader then answers what its own
    # contract forbids, or raises where a customer meets it: a title that is an
    # object, a figure that cannot be a number at all.
    #
    # The rule is the same wherever an operator's form writes preferences, so it
    # is declared once and included rather than repeated per model.
    module PreferenceTypes
      extend ActiveSupport::Concern

      included do
        validate :preferences_must_fit_their_declared_types
      end

      private

      # Refused where an operator writes it rather than where a member meets it.
      # Absent is not a wrong shape — an unset preference is one the reader
      # answers with its default — but anything present must fit what it declares.
      def preferences_must_fit_their_declared_types
        self.class.preference_schema.each do |field|
          value = preferences.to_h[field[:key]]
          next if value.nil? || (value.is_a?(String) && value.blank?)
          next if fits_declared_type?(field[:type], value)

          errors.add(:preferences, :invalid)
          return
        end
      end

      # @param type [Symbol] a declared preference type
      # @param value [Object]
      # @return [Boolean] whether the read that renders it can make sense of the
      #   value. Only the types these models declare are answered for, and one that
      #   arrives as text is still a number if it reads as one — that is what a
      #   JSON or form client sends.
      def fits_declared_type?(type, value)
        case type
        when :string then value.is_a?(String)
        when :integer, :decimal then number_like?(value)
        else true
        end
      end

      # @return [Boolean] whether a value written into a numeric preference is one
      def number_like?(value)
        value.is_a?(Numeric) || (value.is_a?(String) && value.strip.match?(/\A-?\d+(\.\d+)?\z/))
      end
    end
  end
end
