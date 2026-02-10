// Position represents a current holding in a symbol

// Variants over booleans (Manifesto Principle 2)
type positionSide = Long | Short

// Domain-typed primitives (Manifesto Principle 1)
@unboxed type pnl = Pnl(float)

type positionStatus =
  | Open({openedAt: Trade.timestamp})
  | Closed({openedAt: Trade.timestamp, closedAt: Trade.timestamp, realizedPnl: pnl})

type position = {
  symbol: Trade.symbol,
  side: positionSide,
  entryPrice: Trade.price,
  currentQty: Trade.quantity,
  status: positionStatus,
}

let make = (
  ~symbol: Trade.symbol,
  ~side: positionSide,
  ~entryPrice: Trade.price,
  ~qty: Trade.quantity,
  ~openedAt: Trade.timestamp,
): position => {
  symbol,
  side,
  entryPrice,
  currentQty: qty,
  status: Open({openedAt: openedAt}),
}

let unrealizedPnl = (pos: position, currentPrice: Trade.price): pnl => {
  let Trade.Price(entry) = pos.entryPrice
  let Trade.Price(current) = currentPrice
  let Trade.Quantity(qty) = pos.currentQty
  let diff = switch pos.side {
  | Long => current -. entry
  | Short => entry -. current
  }
  Pnl(diff *. qty)
}

// Compute PnL from raw values — avoids constructing a full Position record
let computePnl = (
  ~side: positionSide,
  ~entryPrice: Trade.price,
  ~currentPrice: Trade.price,
  ~qty: Trade.quantity,
): pnl => {
  let Trade.Price(entry) = entryPrice
  let Trade.Price(current) = currentPrice
  let Trade.Quantity(q) = qty
  let diff = switch side {
  | Long => current -. entry
  | Short => entry -. current
  }
  Pnl(diff *. q)
}
