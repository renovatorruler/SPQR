// Paper trading exchange implementation (Decision #4, #12)
// In-memory simulation. Also serves as test double.
// Bounded trade history (Decision #16) — max 1000 trades in memory.
//
// Enhanced: accepts a price feed so paper trades use real market prices
// instead of the old fixed $100 placeholder.

let maxTradesInMemory = 1000

// Internal state — contained mutation (Manifesto Principle 10)
type state = {
  mutable balance: Config.balance,
  mutable trades: array<Trade.trade>,
  mutable positions: array<Position.position>,
  mutable nextTradeId: int,
  mutable currentPrices: Dict.t<Trade.price>,
}

type t = {state: state, config: Config.exchangeConfig}

let make = (config: Config.exchangeConfig): result<t, BotError.t> => {
  let state = {
    balance: Config.Balance(10000.0),
    trades: [],
    positions: [],
    nextTradeId: 1,
    currentPrices: Dict.make(),
  }
  Ok({state, config})
}

// Called by bot loop each tick with real market prices
let setCurrentPrice = (exchange: t, symbol: Trade.symbol, price: Trade.price): unit => {
  let Trade.Symbol(sym) = symbol
  exchange.state.currentPrices->Dict.set(sym, price)
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
  let Trade.Symbol(sym) = symbol
  switch exchange.state.currentPrices->Dict.get(sym) {
  | Some(price) => Promise.resolve(Ok(price))
  | None =>
    Promise.resolve(
      Error(
        BotError.ExchangeError(
          UnknownExchangeError({message: `No price set for ${sym} — call setCurrentPrice first`}),
        ),
      ),
    )
  }
}

let getMarketPrice = (exchange: t, symbol: Trade.symbol, orderType: Trade.orderType): result<Trade.price, BotError.t> => {
  switch orderType {
  | Trade.Limit({limitPrice}) => Ok(limitPrice)
  | Trade.Market =>
    let Trade.Symbol(sym) = symbol
    switch exchange.state.currentPrices->Dict.get(sym) {
    | Some(price) => Ok(price)
    | None =>
      Error(
        BotError.ExchangeError(
          UnknownExchangeError({message: `No market price for ${sym} — call setCurrentPrice first`}),
        ),
      )
    }
  }
}

let placeOrder = (
  exchange: t,
  ~symbol: Trade.symbol,
  ~side: Trade.side,
  ~orderType: Trade.orderType,
  ~qty: Trade.quantity,
): promise<result<Trade.trade, BotError.t>> => {
  switch getMarketPrice(exchange, symbol, orderType) {
  | Error(e) => Promise.resolve(Error(e))
  | Ok(fillPrice) =>
    let Trade.Quantity(qtyFloat) = qty
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
      exchange.state.balance = Config.Balance(currentBalance +. cost)
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
