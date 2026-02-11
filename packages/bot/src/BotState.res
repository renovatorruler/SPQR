// Bot State — in-memory state backed by SQLite persistence
// Tracks regime, bases per symbol, and open position info for QFL strategy

type symbolState = {
  mutable bases: array<BaseDetector.base>,
  mutable openPosition: option<QflStrategy.openPositionInfo>,
}

type t = {
  db: Db.t,
  riskManager: RiskManager.t,
  mutable regime: LlmEvaluator.marketRegime,
  mutable lastRegimeCheck: option<Trade.timestamp>,
  symbolStates: Dict.t<symbolState>,
}

let make = (db: Db.t, riskLimits: Config.riskLimits): t => {
  {
    db,
    riskManager: RiskManager.make(riskLimits),
    regime: LlmEvaluator.Unknown,
    lastRegimeCheck: None,
    symbolStates: Dict.make(),
  }
}

let getSymbolState = (state: t, symbol: Trade.symbol): symbolState => {
  let Trade.Symbol(sym) = symbol
  switch state.symbolStates->Dict.get(sym) {
  | Some(ss) => ss
  | None =>
    let ss = {bases: [], openPosition: None}
    state.symbolStates->Dict.set(sym, ss)
    ss
  }
}

let updateBases = (state: t, symbol: Trade.symbol, bases: array<BaseDetector.base>): unit => {
  let ss = getSymbolState(state, symbol)
  ss.bases = bases
  // Persist to SQLite
  Db.saveBases(state.db, symbol, bases)->ignore
}

let setOpenPosition = (
  state: t,
  symbol: Trade.symbol,
  posInfo: option<QflStrategy.openPositionInfo>,
): unit => {
  let ss = getSymbolState(state, symbol)
  ss.openPosition = posInfo
}

let updateRegime = (state: t, regime: LlmEvaluator.marketRegime): unit => {
  state.regime = regime
  state.lastRegimeCheck = Some(Trade.Timestamp(Date.now()))
  // Persist regime to SQLite
  Db.saveState(state.db, "regime", LlmEvaluator.regimeToString(regime))->ignore
}

let isRegimeStale = (state: t, intervalMs: Config.intervalMs): bool => {
  let Config.IntervalMs(interval) = intervalMs
  switch state.lastRegimeCheck {
  | None => true
  | Some(Trade.Timestamp(lastCheck)) =>
    let now = Date.now()
    (now -. lastCheck) > Float.fromInt(interval)
  }
}

// Restore state from SQLite on restart
let restore = (db: Db.t, riskLimits: Config.riskLimits): result<t, BotError.t> => {
  let state = make(db, riskLimits)

  // Restore open positions
  switch Db.getOpenPositions(db) {
  | Ok(positions) =>
    positions->Array.forEach(pos => {
      // Reconstruct QFL position info from persisted position.
      // Use entry price as approximate base level. Timestamps from position open time.
      let openedAt = switch pos.status {
      | Position.Open({openedAt}) => openedAt
      | Position.Closed({openedAt, _}) => openedAt
      }
      let posInfo: QflStrategy.openPositionInfo = {
        entryPrice: pos.entryPrice,
        base: {
          priceLevel: pos.entryPrice,
          bounceCount: Config.BounceCount(1),
          firstSeen: openedAt,
          lastBounce: openedAt,
          minLevel: pos.entryPrice,
          maxLevel: pos.entryPrice,
        },
      }
      setOpenPosition(state, pos.symbol, Some(posInfo))
      RiskManager.recordOpen(state.riskManager)
    })
    Ok(state)
  | Error(e) => Error(e)
  }
}

// Persist current state to SQLite
let persist = (state: t): result<unit, BotError.t> => {
  Db.saveState(state.db, "regime", LlmEvaluator.regimeToString(state.regime))
}
