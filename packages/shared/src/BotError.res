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

type t =
  | ExchangeError(exchangeErrorKind)
  | ConfigError(configErrorKind)
  | StrategyError(strategyErrorKind)

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
  }
}
