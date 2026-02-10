// Market data interface — abstracts candle/price data source
// Implementations: BinanceMarketData (public API, no auth)

module type S = {
  type t

  let make: Config.marketDataConfig => result<t, BotError.t>

  let getCandles: (
    t,
    ~symbol: Trade.symbol,
    ~interval: Config.interval,
    ~limit: int,
  ) => promise<result<array<Config.candlestick>, BotError.t>>

  let getCurrentPrice: (
    t,
    Trade.symbol,
  ) => promise<result<Trade.price, BotError.t>>
}
