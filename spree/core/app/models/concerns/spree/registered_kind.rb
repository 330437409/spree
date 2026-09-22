module Spree
  # What a registered kind of something is: a plain class a plan owns, named on
  # the wire by `api_type`, and answering a promise or a refusal in the shape the
  # services that call it speak.
  #
  # Deliberately not a model. A grant's kinds and a scenario purchase's are the
  # plans' own classes — a coupon, a membership right, a membership term — and
  # what they share is this vocabulary rather than a table
  # (docs/plans/6.1-grant-and-benefit-primitive.md,
  # docs/plans/6.1-scenario-purchases.md).
  module RegisteredKind
    extend ActiveSupport::Concern

    class_methods do
      # The name a row stores and a picker reads. Derived from the class the way
      # {Spree::Base.api_type} derives it, so a kind that renames its class pins
      # this rather than changing what every stored row means.
      #
      # @return [String]
      def api_type
        to_s.demodulize.underscore
      end

      # The answer a kind gives when it has done what it was asked, so a kind's
      # own service and the caller speak the same shape.
      #
      # @param subject [Object] the thing the kind answered about
      # @return [Spree::ServiceModule::Result]
      def accept(subject)
        Spree::ServiceModule::Result.new(true, subject)
      end

      # …and when it will not: the reason is what the caller is told.
      #
      # @param subject [Object] the thing the kind refused about
      # @param reason [Symbol, String]
      # @return [Spree::ServiceModule::Result]
      def refuse(subject, reason)
        Spree::ServiceModule::Result.new(false, subject, Spree::ServiceModule::ResultError.new(reason))
      end
    end
  end
end
