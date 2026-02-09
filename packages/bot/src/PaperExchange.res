// Paper trading exchange implementation (Decision #4, #12)
// In-memory simulation. Also serves as test double.
// Bounded trade history (Decision #16) — max 1000 trades in memory.

let maxTradesInMemory = 1000

// Internal state — contained mutation (Manifesto Principle 10)
type state = {
  mutable balance: Config.balance,
  mutable trades: array<Trade.trade>,
  mutable positions: array<Position.position>,
  mutable nextTradeId: int,
}

type t = {state: state, config: Config.exchangeConfig}

let make = (config: Config.exchangeConfig): result<t, BotError.t> => {
  let state = {
    balance: Config.Balance(10000.0),
    trades: [],
    positions: [],
    nextTradeId: 1,
  }
  Ok({state, config})
}

let generateTradeId = (exchange: t): Trade.tradeId => {
  let id = exchange.state.nextTradeId
  exchange.state.nextTradeId = id + 1
  Trade.TradeId(`paper-${id->Int.toString}`)
}

let trimTrades = (exchange: t): unit => {
  let len = exchange.state.trades->Array.length
  if len > maxTradesInMemory {
    exchange.state.trades =
      exchange.state.trades->Array.slice(~start=len - maxTradesInMemory, ~end=len)
  }
}

let getPrice = (exchange: t, symbol: Trade.symbol): promise<result<Trade.price, BotError.t>> => {
  // Paper exchange returns a simulated price
  let _ = exchange
  let Trade.Symbol(sym) = symbol
  Logger.debug(`Paper price request for ${sym}`)
  // Placeholder: return a fixed price. Real implementation would use historical data.
  Promise.resolve(Ok(Trade.Price(100.0)))
}

let placeOrder = (
  exchange: t,
  ~symbol: Trade.symbol,
  ~side: Trade.side,
  ~orderType: Trade.orderType,
  ~qty: Trade.quantity,
): promise<result<Trade.trade, BotError.t>> => {
  let Trade.Quantity(qtyFloat) = qty

  // Check balance for buys
  let priceResult = switch orderType {
  | Trade.Market => Ok(Trade.Price(100.0))
  | Trade.Limit({limitPrice}) => Ok(limitPrice)
  }

  switch priceResult {
  | Error(e) => Promise.resolve(Error(e))
  | Ok(fillPrice) =>
    let Trade.Price(priceFloat) = fillPrice
    let cost = priceFloat *. qtyFloat

    let Config.Balance(currentBalance) = exchange.state.balance

    switch side {
    | Trade.Buy if currentBalance < cost =>
      Promise.resolve(
        Error(
          BotError.ExchangeError(
            InsufficientBalance({available: currentBalance, required: cost}),
          ),
        ),
      )
    | Trade.Buy =>
      exchange.state.balance = Config.Balance(currentBalance -. cost)
      let tradeId = generateTradeId(exchange)
      let now = Trade.Timestamp(Date.now())
      let trade = Trade.make(
        ~id=tradeId,
        ~symbol,
        ~side,
        ~orderType,
        ~requestedQty=qty,
        ~createdAt=now,
      )
      // Simulate instant fill
      let filledTrade = {
        ...trade,
        status: Trade.Filled({filledAt: now, filledPrice: fillPrice}),
      }
      exchange.state.trades = exchange.state.trades->Array.concat([filledTrade])
      trimTrades(exchange)

      let Trade.Symbol(sym) = symbol
      Logger.trade(`Paper BUY ${qtyFloat->Float.toString} ${sym} @ ${priceFloat->Float.toString}`)
      Promise.resolve(Ok(filledTrade))

    | Trade.Sell =>
      let Config.Balance(sellBalance) = exchange.state.balance
      exchange.state.balance = Config.Balance(sellBalance +. cost)
      let tradeId = generateTradeId(exchange)
      let now = Trade.Timestamp(Date.now())
      let trade = Trade.make(
        ~id=tradeId,
        ~symbol,
        ~side,
        ~orderType,
        ~requestedQty=qty,
        ~createdAt=now,
      )
      let filledTrade = {
        ...trade,
        status: Trade.Filled({filledAt: now, filledPrice: fillPrice}),
      }
      exchange.state.trades = exchange.state.trades->Array.concat([filledTrade])
      trimTrades(exchange)

      let Trade.Symbol(sym) = symbol
      Logger.trade(`Paper SELL ${qtyFloat->Float.toString} ${sym} @ ${priceFloat->Float.toString}`)
      Promise.resolve(Ok(filledTrade))
    }
  }
}

let getBalance = (exchange: t): promise<result<Config.balance, BotError.t>> => {
  Promise.resolve(Ok(exchange.state.balance))
}

let getOpenPositions = (exchange: t): promise<result<array<Position.position>, BotError.t>> => {
  Promise.resolve(Ok(exchange.state.positions))
}
