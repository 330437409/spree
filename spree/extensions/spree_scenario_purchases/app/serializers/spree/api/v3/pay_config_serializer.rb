module Spree
  module Api
    module V3
      # What can be bought here and how: the channels with a gateway behind
      # them, what each kind sells, and whether this customer has a PIN to
      # enter.
      class PayConfigSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize channels: 'Array<Record<string, unknown>>',
                 kinds: 'Array<Record<string, unknown>>', payment_pin: :boolean

        attribute(:channels) { |config| config.channels }
        attribute(:kinds) { |config| config.kinds }
        attribute(:payment_pin) { |config| config.payment_pin? }
      end
  end
end
end
