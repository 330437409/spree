module Spree
  module Api
    module V3
      # The member day as its page and the home page's popup both render it: the
      # day, whether it is today, what it earns, and the operator's copy around it.
      #
      # Deliberately not a `BaseSerializer`: a day is a reading of a tier's right
      # rather than a record, so it has no id and nothing to update.
      class MemberDaySerializer
        include Alba::Resource
        include Typelizer::DSL
        include MembershipMoney

        typelize name: 'string | null', today: :boolean, line: 'string | null', times: :number,
                 minimum_amount: 'string | null', qualifying_kinds: 'Array<string>',
                 rights_red: :boolean, rights_red_money: 'string | null',
                 rule: 'string | null', share_title: 'string | null', share_icon: 'string | null'

        attribute(:name) { |day| day.day_name }
        attribute(:today) { |day| day.today? }
        # The day in the customer's own words, rendered rather than typed.
        attribute(:line) { |day| day.line }
        attribute(:times) { |day| day.times }
        attribute(:minimum_amount) { |day| decimal(day.minimum_amount) }
        attribute(:qualifying_kinds) { |day| day.qualifying_kinds }
        attribute(:rights_red) { |day| day.rights_red? }
        attribute(:rights_red_money) { |day| decimal(day.rights_red_money) }
        attribute(:rule) { |day| day.rule }
        attribute(:share_title) { |day| day.share_title }
        attribute(:share_icon) { |day| day.share_icon }
      end
    end
  end
end
