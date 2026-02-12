// Backtesting types shared between bot and dashboard

@unboxed type basisPoints = BasisPoints(float)
@unboxed type tradeCount = TradeCount(int)
@unboxed type winRate = WinRate(float)
@unboxed type drawdownPercent = DrawdownPercent(float)
@unboxed type returnPercent = ReturnPercent(float)

type feeModel =
  | NoFees
  | FixedBps({bps: basisPoints})

type slippageModel =
  | NoSlippage
  | FixedBps({bps: basisPoints})

type backtestWindow = {
  start: Trade.timestamp,
  end_: Trade.timestamp,
}

type backtestConfig = {
  window: backtestWindow,
  interval: Config.interval,
  initialBalance: Config.balance,
  feeModel: feeModel,
  slippageModel: slippageModel,
}

type equityPoint = {
  time: Trade.timestamp,
  balance: Config.balance,
}

type metrics = {
  totalTrades: tradeCount,
  winRate: winRate,
  totalReturn: returnPercent,
  maxDrawdown: drawdownPercent,
}

type result = {
  trades: array<Trade.trade>,
  equityCurve: array<equityPoint>,
  metrics: metrics,
}
