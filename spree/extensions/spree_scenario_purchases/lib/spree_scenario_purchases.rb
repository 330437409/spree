require 'spree_core'
require 'spree_scenario_purchases/engine'

# The purchases that are not orders: a membership term, points, a card, a
# coupon bundle, a place in a group buy. The mini program pays for each of them
# the same way — one call, one payment, one entitlement — and Spree had the
# payment half and none of the first.
#
# This gem owns that first half once: a row that says what was bought and in
# which channel, the reads the client's own screens are built on, and the
# settlement that hands the entitlement to the plan which owns it
# (docs/plans/6.1-scenario-purchases.md).
module SpreeScenarioPurchases
  # The kinds of scenario purchase a deployment sells, each a class answering
  # what it costs, what settling it issues and what refunding it takes back. A
  # registry rather than a branch, so a kind is a class another gem registers
  # without editing this one.
  #
  # Empty on purpose: the frame ships before the kinds, and each arrives with
  # the plan that owns the thing being bought.
  def self.scenario_order_kinds
    @scenario_order_kinds ||= []
  end

  # Which payment method serves which channel. The frame stores the channel a
  # purchase was made in; this is how that is resolved to the gateway that
  # takes the money. ChinaUMS is the withdrawn seam — named, unserved, and
  # unroutable until a gateway exists for it (`decisions.md`, 2026-09-18).
  CHANNELS = {
    'wechat' => 'SpreeWechatPay::Gateway',
    'chinaums' => nil
  }.freeze

  # The gateway that takes a channel's money, if the store has one active. One
  # resolution point, so what `pay_config` offers and what a purchase is allowed
  # to use can never disagree: an unserved channel — ChinaUMS today — is a
  # column value with no method behind it.
  #
  # @param store [Spree::Store, nil]
  # @param channel [String]
  # @return [Spree::PaymentMethod, nil]
  def self.payment_method_for(store, channel)
    class_name = CHANNELS[channel]
    return nil if class_name.nil? || store.nil?

    store.payment_methods.active.find_by(type: class_name)
  end
end
