module Spree
  module ReverseGeocode
    # What a lookup answered: the path, who answered it, and where it came from.
    #
    # A stale answer — a cached one served because the providers were
    # unreachable — is still an answer, and it says so rather than passing
    # itself off as fresh. An empty path is an answer too: the point is in no
    # division this tree carries.
    class Resolution
      attr_reader :path, :provider

      def initialize(path:, provider: nil, cached: false, stale: false)
        @path = path
        @provider = provider
        @cached = cached
        @stale = stale
      end

      def resolved?
        path.present?
      end

      def cached?
        @cached
      end

      def stale?
        @stale
      end
    end
  end
end
