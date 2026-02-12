// Risk Manager — enforces risk limits, triggers hard stop
//
// When any limit is breached, the bot halts (hard stop).
// Limits checked: max daily loss, max open positions, max position size.

type riskCheck =
  | Allowed
  | Blocked(BotError.t)

type t = {
  config: Config.riskLimits,
  mutable dailyPnl: Position.pnl,
  mutable openPositionCount: Config.openPositionsCount,
  mutable halted: bool,
}

let make = (config: Config.riskLimits): t => {
  {
    config,
    dailyPnl: Position.Pnl(0.0),
    openPositionCount: Config.OpenPositionsCount(0),
    halted: false,
  }
}

let isHalted = (rm: t): bool => rm.halted

let checkEntry = (
  rm: t,
  ~qty: Trade.quantity,
  ~price: Trade.price,
): riskCheck => {
  if rm.halted {
    Blocked(BotError.RiskError(MaxDailyLossReached({currentLoss: 0.0, limit: 0.0})))
  } else {
    let Trade.Quantity(qtyFloat) = qty
    let Trade.Price(priceFloat) = price
    let positionValue = qtyFloat *. priceFloat
    let Trade.Quantity(maxSize) = rm.config.maxPositionSize

    // Check position size
    if positionValue > maxSize {
      let err = BotError.RiskError(
        MaxPositionSizeExceeded({requested: positionValue, limit: maxSize}),
      )
      rm.halted = true
      Blocked(err)
    } else {
      let Config.OpenPositionsCount(currentCount) = rm.openPositionCount
      let Config.MaxOpenPositions(limitCount) = rm.config.maxOpenPositions
      if currentCount >= limitCount {
        // Check open position count
        let err = BotError.RiskError(
          MaxOpenPositionsReached({current: rm.openPositionCount, limit: rm.config.maxOpenPositions}),
        )
        rm.halted = true
        Blocked(err)
      } else {
        // Check daily loss
        let Position.Pnl(currentLoss) = rm.dailyPnl
        let Position.Pnl(maxLoss) = rm.config.maxDailyLoss
        let absLoss = if currentLoss < 0.0 { -.currentLoss } else { currentLoss }
        if currentLoss < 0.0 && absLoss >= maxLoss {
          let err = BotError.RiskError(
            MaxDailyLossReached({currentLoss: absLoss, limit: maxLoss}),
          )
          rm.halted = true
          Blocked(err)
        } else {
          Allowed
        }
      }
    }
  }
}

let recordOpen = (rm: t): unit => {
  let Config.OpenPositionsCount(currentCount) = rm.openPositionCount
  rm.openPositionCount = Config.OpenPositionsCount(currentCount + 1)
}

let recordClose = (rm: t, pnl: Position.pnl): unit => {
  let Config.OpenPositionsCount(currentCount) = rm.openPositionCount
  let newCount = currentCount - 1
  let normalizedCount = if newCount > 0 { newCount } else { 0 }
  rm.openPositionCount = Config.OpenPositionsCount(normalizedCount)
  let Position.Pnl(currentPnl) = rm.dailyPnl
  let Position.Pnl(tradePnl) = pnl
  rm.dailyPnl = Position.Pnl(currentPnl +. tradePnl)
}

let resetDaily = (rm: t): unit => {
  rm.dailyPnl = Position.Pnl(0.0)
  rm.halted = false
}
