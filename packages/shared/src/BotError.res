// Errors as values (Manifesto Principle 7)
// All expected failures are variants, not exceptions

type exchangeErrorKind =
  | ConnectionFailed({url: string, message: string})
  | AuthenticationFailed
  | RateLimited({retryAfterMs: int})
  | InsufficientBalance({available: float, required: float})
  | OrderRejected({reason: string})
  | UnknownExchangeError({message: string})

type configErrorKind =
  | FileNotFound({path: string})
  | ParseFailed({message: string})
  | MissingField({fieldName: string})
  | InvalidValue({fieldName: string, given: string, expected: string})

type strategyErrorKind =
  | InsufficientData({required: int, available: int})
  | InvalidSignal({message: string})

type marketDataErrorKind =
  | FetchFailed({symbol: string, interval: string, message: string})
  | InvalidCandleData({message: string})
  | MarketDataRateLimited({retryAfterMs: int})

type llmErrorKind =
  | ApiCallFailed({message: string})
  | InvalidLlmResponse({message: string})
  | LlmRateLimited({retryAfterMs: int})

type riskErrorKind =
  | MaxDailyLossReached({currentLoss: float, limit: float})
  | MaxOpenPositionsReached({current: int, limit: int})
  | MaxPositionSizeExceeded({requested: float, limit: float})

type engineErrorKind =
  | InitializationFailed({message: string})
  | TickFailed({symbol: string, message: string})
  | ShutdownFailed({message: string})
  | AlreadyRunning
  | NotRunning

type t =
  | ExchangeError(exchangeErrorKind)
  | ConfigError(configErrorKind)
  | StrategyError(strategyErrorKind)
  | MarketDataError(marketDataErrorKind)
  | LlmError(llmErrorKind)
  | RiskError(riskErrorKind)
  | EngineError(engineErrorKind)

// Exhaustive matching (Manifesto Principle 6) — no wildcards
let toString = (error: t): string => {
  switch error {
  | ExchangeError(kind) =>
    switch kind {
    | ConnectionFailed({url, message}) => `Exchange connection failed (${url}): ${message}`
    | AuthenticationFailed => "Exchange authentication failed"
    | RateLimited({retryAfterMs}) => `Rate limited, retry after ${retryAfterMs->Int.toString}ms`
    | InsufficientBalance({available, required}) =>
      `Insufficient balance: have ${available->Float.toString}, need ${required->Float.toString}`
    | OrderRejected({reason}) => `Order rejected: ${reason}`
    | UnknownExchangeError({message}) => `Exchange error: ${message}`
    }
  | ConfigError(kind) =>
    switch kind {
    | FileNotFound({path}) => `Config file not found: ${path}`
    | ParseFailed({message}) => `Config parse failed: ${message}`
    | MissingField({fieldName}) => `Missing config field: ${fieldName}`
    | InvalidValue({fieldName, given, expected}) =>
      `Invalid config value for ${fieldName}: got "${given}", expected ${expected}`
    }
  | StrategyError(kind) =>
    switch kind {
    | InsufficientData({required, available}) =>
      `Insufficient data: need ${required->Int.toString} candles, have ${available->Int.toString}`
    | InvalidSignal({message}) => `Invalid signal: ${message}`
    }
  | MarketDataError(kind) =>
    switch kind {
    | FetchFailed({symbol, interval, message}) =>
      `Market data fetch failed for ${symbol} (${interval}): ${message}`
    | InvalidCandleData({message}) => `Invalid candle data: ${message}`
    | MarketDataRateLimited({retryAfterMs}) =>
      `Market data rate limited, retry after ${retryAfterMs->Int.toString}ms`
    }
  | LlmError(kind) =>
    switch kind {
    | ApiCallFailed({message}) => `LLM API call failed: ${message}`
    | InvalidLlmResponse({message}) => `Invalid LLM response: ${message}`
    | LlmRateLimited({retryAfterMs}) =>
      `LLM rate limited, retry after ${retryAfterMs->Int.toString}ms`
    }
  | RiskError(kind) =>
    switch kind {
    | MaxDailyLossReached({currentLoss, limit}) =>
      `Max daily loss reached: ${currentLoss->Float.toString} >= ${limit->Float.toString}`
    | MaxOpenPositionsReached({current, limit}) =>
      `Max open positions reached: ${current->Int.toString} >= ${limit->Int.toString}`
    | MaxPositionSizeExceeded({requested, limit}) =>
      `Max position size exceeded: ${requested->Float.toString} > ${limit->Float.toString}`
    }
  | EngineError(kind) =>
    switch kind {
    | InitializationFailed({message}) => `Engine initialization failed: ${message}`
    | TickFailed({symbol, message}) => `Tick failed for ${symbol}: ${message}`
    | ShutdownFailed({message}) => `Shutdown failed: ${message}`
    | AlreadyRunning => "Engine is already running"
    | NotRunning => "Engine is not running"
    }
  }
}
