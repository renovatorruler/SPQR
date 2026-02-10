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

type botConfig = {
  tradingMode: tradingMode,
  exchange: exchangeConfig,
  symbols: array<Trade.symbol>,
  riskLimits: riskLimits,
}
