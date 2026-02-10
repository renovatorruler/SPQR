// Shared config types used by both bot and dashboard
// Bot-specific config loading is in packages/bot/src/BotConfig.res

// Domain-typed primitives (Manifesto Principle 1)
@unboxed type apiKey = ApiKey(string)
@unboxed type apiSecret = ApiSecret(string)
@unboxed type baseUrl = BaseUrl(string)
@unboxed type balance = Balance(float)

// Variants over strings (Manifesto Principle 2)
type exchangeId =
  | Binance
  | Uniswap
  | Jupiter
  | PaperExchange

type tradingMode =
  | Paper
  | Live

type exchangeConfig = {
  exchangeId: exchangeId,
  baseUrl: option<baseUrl>,
  apiKey: option<apiKey>,
  apiSecret: option<apiSecret>,
}

type riskLimits = {
  maxPositionSize: Trade.quantity,
  maxOpenPositions: int,
  maxDailyLoss: Position.pnl,
}

// Domain-typed primitives for market data and strategy (Manifesto Principle 1)
@unboxed type interval = Interval(string) // "1m", "5m", "15m", "1h", "4h", "1d", "1w"
@unboxed type volume = Volume(float)
@unboxed type crackPercent = CrackPercent(float)
@unboxed type stopLossPercent = StopLossPercent(float)
@unboxed type takeProfitPercent = TakeProfitPercent(float)
@unboxed type bounceCount = BounceCount(int)
@unboxed type candleCount = CandleCount(int)
@unboxed type confidence = Confidence(float)

// Candle data for market analysis
type candlestick = {
  openTime: Trade.timestamp,
  open_: Trade.price,
  high: Trade.price,
  low: Trade.price,
  close: Trade.price,
  volume: volume,
  closeTime: Trade.timestamp,
}

// QFL strategy config

type qflConfig = {
  crackThreshold: crackPercent,
  stopLossThreshold: stopLossPercent,
  takeProfitTarget: takeProfitPercent,
  minBouncesForBase: bounceCount,
  lookbackCandles: candleCount,
}

// LLM config for regime analysis and setup evaluation
@unboxed type llmApiKey = LlmApiKey(string)
@unboxed type llmModel = LlmModel(string)

@unboxed type intervalMs = IntervalMs(int)

type llmConfig = {
  apiKey: llmApiKey,
  model: llmModel,
  regimeCheckIntervalMs: intervalMs,
  evaluateSetups: bool,
}

// Market data source
type marketDataSource =
  | BinancePublic
  | BinanceUS
  | CustomSource({baseUrl: baseUrl})

type marketDataConfig = {
  source: marketDataSource,
  defaultInterval: interval,
}

// Engine config
@unboxed type pollIntervalMs = PollIntervalMs(int)

type engineConfig = {
  pollIntervalMs: pollIntervalMs,
  closeOnShutdown: bool,
}

type botConfig = {
  tradingMode: tradingMode,
  exchange: exchangeConfig,
  symbols: array<Trade.symbol>,
  riskLimits: riskLimits,
  qfl: qflConfig,
  llm: option<llmConfig>,
  marketData: marketDataConfig,
  engine: engineConfig,
}
