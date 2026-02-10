// Base scanner strategy — first implementation of Strategy interface (Decision #6)
// Currently a placeholder that always returns Hold.
// Will be implemented when the trading strategy is defined.

// Uses Strategy.signal type from Strategy.resi — no duplicate type definition

let analyze = (prices: array<Trade.price>): result<Strategy.signal, BotError.t> => {
  let dataPoints = prices->Array.length
  if dataPoints == 0 {
    Error(BotError.StrategyError(InsufficientData({required: 1, available: 0})))
  } else {
    // Placeholder: always hold. Replace with real strategy logic.
    Logger.debug(`BaseScanner analyzed ${dataPoints->Int.toString} price points — holding`)
    Ok(Strategy.Hold)
  }
}
