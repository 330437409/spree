module Spree
  module Api
    module V3
      # One line of the savings popup: a heading and the body under it.
      #
      # Deliberately not a `BaseSerializer`: the row is a pair of strings the
      # tier's own settings produce, so there is no id and nothing to update.
      # A blank side stays blank — the client skips a row it cannot print, which
      # is how an operator leaves one of the four out.
      class MembershipSavingRowSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize title: 'string | null', content: 'string | null'

        attribute(:title) { |row| row['title'].presence }
        attribute(:content) { |row| row['content'].presence }
      end
    end
  end
end
