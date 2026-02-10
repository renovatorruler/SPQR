// QFL (Quick Fingers Luc) Strategy — Stop-Loss Model
//
// 1. Detect bases (support levels) from candle data
// 2. When price cracks below a base by crackThreshold% → BUY signal
// 3. When price returns to base level → SELL (take profit)
// 4. When price drops stopLossThreshold% below entry → SELL (stop loss)
// 5. After stop loss: wait for price to settle into new channel, detect new bases
//
// This is the stop-loss model. The fractal cascade model (zoom out to bigger
// timeframes instead of stop loss) will be added later as an alternative.

type qflSignal =
  | CrackDetected({
      base: BaseDetector.base,
      currentPrice: Trade.price,
      crackPercent: Config.crackPercent,
      symbol: Trade.symbol,
    })
  | BounceBack({
      entryPrice: Trade.price,
      currentPrice: Trade.price,
      base: BaseDetector.base,
      symbol: Trade.symbol,
    })
  | StopLossTriggered({
      entryPrice: Trade.price,
      currentPrice: Trade.price,
      lossPercent: Config.stopLossPercent,
      symbol: Trade.symbol,
    })
  | NoSignal

// Check if current price has cracked below any base
let checkForCrack = (
  ~bases: array<BaseDetector.base>,
  ~currentPrice: Trade.price,
  ~crackThreshold: Config.crackPercent,
  ~symbol: Trade.symbol,
): qflSignal => {
  let Trade.Price(price) = currentPrice
  let Config.CrackPercent(threshold) = crackThreshold

  // Find the nearest base that price has cracked below
  let cracked =
    bases->Array.filterMap(base => {
      let Trade.Price(baseLevel) = base.priceLevel
      let percentBelow = ((baseLevel -. price) /. baseLevel) *. 100.0
      switch percentBelow >= threshold {
      | true => Some((base, percentBelow))
      | false => None
      }
    })

  // Take the strongest (most bounces) cracked base
  switch cracked->Array.get(0) {
  | Some((base, crackPct)) =>
    CrackDetected({base, currentPrice, crackPercent: Config.CrackPercent(crackPct), symbol})
  | None => NoSignal
  }
}

// Check if price has bounced back to base (take profit)
let checkForBounce = (
  ~entryPrice: Trade.price,
  ~currentPrice: Trade.price,
  ~base: BaseDetector.base,
  ~symbol: Trade.symbol,
): qflSignal => {
  let Trade.Price(current) = currentPrice
  let Trade.Price(baseLevel) = base.priceLevel

  switch current >= baseLevel {
  | true => BounceBack({entryPrice, currentPrice, base, symbol})
  | false => NoSignal
  }
}

// Check if stop loss should trigger
let checkStopLoss = (
  ~entryPrice: Trade.price,
  ~currentPrice: Trade.price,
  ~stopLossThreshold: Config.stopLossPercent,
  ~symbol: Trade.symbol,
): qflSignal => {
  let Trade.Price(entry) = entryPrice
  let Trade.Price(current) = currentPrice
  let Config.StopLossPercent(threshold) = stopLossThreshold
  let lossPercent = ((entry -. current) /. entry) *. 100.0

  switch lossPercent >= threshold {
  | true => StopLossTriggered({entryPrice, currentPrice, lossPercent: Config.StopLossPercent(lossPercent), symbol})
  | false => NoSignal
  }
}

// Open position info needed for exit signal checks
type openPositionInfo = {
  entryPrice: Trade.price,
  base: BaseDetector.base,
}

// Main analysis function
let analyze = (
  ~candles: array<Config.candlestick>,
  ~currentPrice: Trade.price,
  ~symbol: Trade.symbol,
  ~config: Config.qflConfig,
  ~openPosition: option<openPositionInfo>,
): result<qflSignal, BotError.t> => {
  if candles->Array.length < 3 {
    Error(BotError.StrategyError(InsufficientData({required: 3, available: candles->Array.length})))
  } else {
    // Detect bases from candle history
    let baseResult = BaseDetector.detectBases(candles, ~minBounces=config.minBouncesForBase)

    switch openPosition {
    | Some({entryPrice, base}) =>
      // We have an open position — check for exit signals first
      // Priority: stop loss > take profit
      let stopLoss = checkStopLoss(
        ~entryPrice,
        ~currentPrice,
        ~stopLossThreshold=config.stopLossThreshold,
        ~symbol,
      )
      switch stopLoss {
      | StopLossTriggered(_) => Ok(stopLoss)
      | _ =>
        let bounce = checkForBounce(~entryPrice, ~currentPrice, ~base, ~symbol)
        Ok(bounce)
      }

    | None =>
      // No open position — check for entry signals
      switch baseResult {
      | BaseDetector.NoBases => Ok(NoSignal)
      | BaseDetector.BasesFound({bases}) =>
        Ok(
          checkForCrack(
            ~bases,
            ~currentPrice,
            ~crackThreshold=config.crackThreshold,
            ~symbol,
          ),
        )
      }
    }
  }
}
