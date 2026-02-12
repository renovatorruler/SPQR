// Shared config types used by both bot and dashboard
// Bot-specific config loading is in packages/bot/src/BotConfig.res

// Domain-typed primitives (Manifesto Principle 1)
@unboxed type apiKey = ApiKey(string)
@unboxed type apiSecret = ApiSecret(string)
@unboxed type baseUrl = BaseUrl(string)
@unboxed type balance = Balance(float)
@unboxed type maxOpenPositions = MaxOpenPositions(int)
@unboxed type openPositionsCount = OpenPositionsCount(int)

// Variants over strings (Manifesto Principle 2)
type exchangeId =
  | Binance
  | Kraken
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
  maxOpenPositions: maxOpenPositions,
  maxDailyLoss: Position.pnl,
}

// Variants over strings — candle interval (Manifesto Principle 2)
type interval =
  | @as("1m") OneMinute
  | @as("5m") FiveMinutes
  | @as("15m") FifteenMinutes
  | @as("1h") OneHour
  | @as("4h") FourHours
  | @as("1d") OneDay
  | @as("1w") OneWeek

let intervalToString = (i: interval): string =>
  switch i {
  | OneMinute => "1m"
  | FiveMinutes => "5m"
  | FifteenMinutes => "15m"
  | OneHour => "1h"
  | FourHours => "4h"
  | OneDay => "1d"
  | OneWeek => "1w"
  }

// Domain-typed primitives for market data and strategy (Manifesto Principle 1)
@unboxed type volume = Volume(float)
@unboxed type crackPercent = CrackPercent(float)
@unboxed type stopLossPercent = StopLossPercent(float)
@unboxed type takeProfitPercent = TakeProfitPercent(float)
@unboxed type bounceCount = BounceCount(int)
@unboxed type candleCount = CandleCount(int)
@unboxed type confidence = Confidence(float)
@unboxed type tolerancePercent = TolerancePercent(float)
@unboxed type driftPercent = DriftPercent(float)
@unboxed type emaPeriod = EmaPeriod(int)
@unboxed type emaSlopeLookback = EmaSlopeLookback(int)
@unboxed type holdCandles = HoldCandles(int)
@unboxed type cooldownCandles = CooldownCandles(int)
@unboxed type weight = Weight(float)
@unboxed type timeoutMs = TimeoutMs(int)
@unboxed type minYesVotes = MinYesVotes(int)

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

type regimeGateConfig = {
  emaFast: emaPeriod,
  emaSlow: emaPeriod,
  emaSlopeLookback: emaSlopeLookback,
}

type baseFilterConfig = {
  minBounces: bounceCount,
  tolerance: tolerancePercent,
  maxBaseDrift: driftPercent,
}

type exitPolicy = {
  stopLoss: stopLossPercent,
  takeProfit: takeProfitPercent,
  maxHold: holdCandles,
}

type reentryPolicy =
  | NoReentry
  | ReentryOnce({cooldown: cooldownCandles})

type llmProvider =
  | OpenRouter
  | OpenAI
  | Anthropic
  | Google
  | Mistral
  | Cohere
  | Local

@unboxed type llmApiKey = LlmApiKey(string)
@unboxed type llmModel = LlmModel(string)
@unboxed type llmModelId = LlmModelId(string)
@unboxed type llmBaseUrl = LlmBaseUrl(string)

type llmMember = {
  provider: llmProvider,
  modelId: llmModelId,
  apiKey: llmApiKey,
  apiBase: llmBaseUrl,
  weight: weight,
  timeout: timeoutMs,
}

type voteRule =
  | SimpleMajority
  | SuperMajority({minYes: minYesVotes})
  | WeightedMajority({minWeight: weight})

type committeeConfig = {
  members: array<llmMember>,
  rule: voteRule,
  minConfidence: confidence,
}

type setupEvaluation =
  | Disabled
  | Committee(committeeConfig)

type qflConfig = {
  crackThreshold: crackPercent,
  baseFilter: baseFilterConfig,
  exitPolicy: exitPolicy,
  reentry: reentryPolicy,
  regimeGate: regimeGateConfig,
  setupEvaluation: setupEvaluation,
  lookbackCandles: candleCount,
}

@unboxed type intervalMs = IntervalMs(int)

type llmConfig = {
  apiKey: llmApiKey,
  model: llmModel,
  regimeCheckIntervalMs: intervalMs,
  evaluateSetups: bool,
}

// Market data source — CCXT unified exchange library
// ccxtExchangeId is a string wrapper for CCXT's 100+ dynamic exchange names (e.g. "kraken", "binance")
// distinct from exchangeId variant which enumerates supported exchanges at compile time
@unboxed type ccxtExchangeId = CcxtExchangeId(string)

type marketDataSource =
  | Ccxt({exchangeId: ccxtExchangeId})

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
