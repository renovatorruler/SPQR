type side = Buy | Sell
type status = Open | Closed | Cancelled

type trade = {
  id: string,
  symbol: string,
  side: side,
  price: float,
  quantity: float,
  status: status,
  timestamp: float,
}

let openTrades: array<trade> = []

let create = (~id, ~symbol, ~side, ~price, ~quantity) => {
  id,
  symbol,
  side,
  price,
  quantity,
  status: Open,
  timestamp: Date.now(),
}
