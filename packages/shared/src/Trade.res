// Domain-typed primitives (Manifesto Principle 1)
@unboxed type tradeId = TradeId(string)
@unboxed type symbol = Symbol(string)
@unboxed type price = Price(float)
@unboxed type quantity = Quantity(float)
@unboxed type timestamp = Timestamp(float)

// Variants over booleans (Manifesto Principle 2)
type side = Buy | Sell

type orderType =
  | Market
  | Limit({limitPrice: price})

type tradeStatus =
  | Pending
  | Filled({filledAt: timestamp, filledPrice: price})
  | PartiallyFilled({filledQty: quantity, remainingQty: quantity, avgPrice: price})
  | Cancelled({cancelledAt: timestamp, reason: string})
  | Rejected({rejectedAt: timestamp, reason: string})

// No default values (Manifesto Principle 3) — all fields required when Filled
type trade = {
  id: tradeId,
  symbol: symbol,
  side: side,
  orderType: orderType,
  requestedQty: quantity,
  status: tradeStatus,
  createdAt: timestamp,
}

let make = (
  ~id: tradeId,
  ~symbol: symbol,
  ~side: side,
  ~orderType: orderType,
  ~requestedQty: quantity,
  ~createdAt: timestamp,
): trade => {
  id,
  symbol,
  side,
  orderType,
  requestedQty,
  status: Pending,
  createdAt,
}
