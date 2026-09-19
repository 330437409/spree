module SpreePriceContexts
  # The three contexts, by the code the client sends and the name a channel
  # carries when the installer creates it: 区域, 现场推广 (分销) and 线下.
  #
  # **The codes are the contract.** They are what the client puts in
  # `X-Spree-Channel` and what the operator's channel must be called for the
  # request to resolve one; the names are only a starting point the operator
  # renames at will. Codes are fixed while names are not, which is why the
  # client's own `cartType` words are used rather than a translation of them.
  #
  # A fourth context needs no entry here: an operator creates a channel with
  # whatever code its pages send, and every read prices through it.
  CONTEXTS = {
    'area' => 'price_contexts.contexts.area',
    'scene' => 'price_contexts.contexts.scene',
    'offline' => 'price_contexts.contexts.offline'
  }.freeze
end
