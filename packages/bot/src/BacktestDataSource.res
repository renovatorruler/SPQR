// Backtest data source interface

module type S = {
  type t

  let make: (~paths: Dict.t<string>) => t

  let loadCandles: (
    t,
    ~symbol: Trade.symbol,
    ~window: Backtest.backtestWindow,
    ~interval: Config.interval,
  ) => result<array<Config.candlestick>, BotError.t>
}
