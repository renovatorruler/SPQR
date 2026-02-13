// Trade Executor — handles order placement and post-trade bookkeeping
//
// Extracted from BotLoop.processSymbol to deduplicate the sell logic
// (BounceBack and StopLoss were near-identical 30-line blocks) and
// centralize the trade → persist → risk → state update sequence.

type buyResult =
  | Bought
  | RiskBlocked

type sellResult =
  | Sold({pnl: Position.pnl})
  | NoPosition

// Execute a buy order: risk check → place order → persist → update state
let executeBuy = async (
  ~exchange: PaperExchange.t,
  ~db: Db.t,
  ~state: BotState.t,
  ~symbol: Trade.symbol,
  ~currentPrice: Trade.price,
  ~qty: Trade.quantity,
  ~base: BaseDetector.base,
): result<buyResult, BotError.t> => {
  let Trade.Symbol(sym) = symbol

  switch RiskManager.checkEntry(state.riskManager, ~qty, ~price=currentPrice) {
  | RiskManager.Blocked(err) =>
    Logger.error(`${sym}: RISK BLOCKED — ${BotError.toString(err)}`)
    Ok(RiskBlocked)
  | RiskManager.Allowed =>
    let orderResult = await PaperExchange.placeOrder(
      exchange,
      ~symbol,
      ~side=Trade.Buy,
      ~orderType=Trade.Market,
      ~qty,
    )
    switch orderResult {
    | Ok(trade) =>
      switch Db.insertTrade(db, trade) {
      | Ok() => ()
      | Error(e) => Logger.error(`${sym}: Failed to persist trade: ${BotError.toString(e)}`)
      }
      let pos = Position.make(
        ~symbol,
        ~side=Position.Long,
        ~entryPrice=currentPrice,
        ~qty,
        ~openedAt=Trade.Timestamp(Date.now()),
      )
      switch Db.insertPosition(db, pos) {
      | Ok() => ()
      | Error(e) => Logger.error(`${sym}: Failed to persist position: ${BotError.toString(e)}`)
      }
      RiskManager.recordOpen(state.riskManager)
      BotState.setOpenPosition(state, symbol, Some({entryPrice: currentPrice, qty, base}))
      Logger.trade(`${sym}: BUY executed`)
      Ok(Bought)
    | Error(e) =>
      Logger.error(`${sym}: Order failed — ${BotError.toString(e)}`)
      Error(e)
    }
  }
}

// Execute a sell order: place order → persist → compute PnL → update state
// Unified handler for both take-profit (BounceBack) and stop-loss exits.
let executeSell = async (
  ~exchange: PaperExchange.t,
  ~db: Db.t,
  ~state: BotState.t,
  ~symbol: Trade.symbol,
  ~entryPrice: Trade.price,
  ~currentPrice: Trade.price,
  ~qty: Trade.quantity,
  ~reason: string,
): result<sellResult, BotError.t> => {
  let Trade.Symbol(sym) = symbol

  let orderResult = await PaperExchange.placeOrder(
    exchange,
    ~symbol,
    ~side=Trade.Sell,
    ~orderType=Trade.Market,
    ~qty,
  )
  switch orderResult {
  | Ok(trade) =>
    switch Db.insertTrade(db, trade) {
    | Ok() => ()
    | Error(e) => Logger.error(`${sym}: Failed to persist trade: ${BotError.toString(e)}`)
    }
    let pnl = Position.computePnl(
      ~side=Position.Long,
      ~entryPrice,
      ~currentPrice,
      ~qty,
    )
    RiskManager.recordClose(state.riskManager, pnl)
    BotState.setOpenPosition(state, symbol, None)
    let Position.Pnl(pnlVal) = pnl
    Logger.trade(`${sym}: SELL (${reason}) PnL: ${pnlVal->Float.toFixed(~digits=2)}`)
    Ok(Sold({pnl: pnl}))
  | Error(e) =>
    Logger.error(`${sym}: Sell failed — ${BotError.toString(e)}`)
    Error(e)
  }
}
