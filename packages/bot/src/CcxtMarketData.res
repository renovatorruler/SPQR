// CCXT unified market data — supports 100+ exchanges
// Drop-in replacement for BinanceMarketData
// Exchange selection via config: "kraken", "binance", "coinbase", etc.

type t = {
  config: Config.marketDataConfig,
  exchange: CcxtBindings.exchange,
}

// Symbol format conversion: "BTCUSDT" → "BTC/USDT" for CCXT unified API
let toUnifiedSymbol = (symbol: Trade.symbol): string => {
  let Trade.Symbol(sym) = symbol
  let quoteCurrencies = ["USDT", "USDC", "BUSD", "USD", "BTC", "ETH", "BNB", "EUR"]

  let found = quoteCurrencies->Array.find(quote => sym->String.endsWith(quote))
  switch found {
  | Some(quote) =>
    let base = sym->String.slice(~start=0, ~end=sym->String.length - quote->String.length)
    `${base}/${quote}`
  | None => sym
  }
}

let make = (config: Config.marketDataConfig): result<t, BotError.t> => {
  let Config.Ccxt({exchangeId: Config.ExchangeName(id)}) = config.source
  try {
    let exchange = CcxtBindings.createExchange(id)
    Ok({config, exchange})
  } catch {
  | JsExn(jsExn) =>
    let msg = jsExn->JsExn.message->Option.getOr("Unknown error")
    Error(
      BotError.MarketDataError(
        FetchFailed({symbol: "", interval: "", message: `Failed to create CCXT exchange "${id}": ${msg}`}),
      ),
    )
  | _ =>
    Error(
      BotError.MarketDataError(
        FetchFailed({symbol: "", interval: "", message: `Failed to create CCXT exchange "${id}"`}),
      ),
    )
  }
}

// Parse CCXT OHLCV row: [timestamp, open, high, low, close, volume]
let parseOhlcvRow = (row: array<float>): option<Config.candlestick> => {
  switch (row[0], row[1], row[2], row[3], row[4], row[5]) {
  | (Some(timestamp), Some(open_), Some(high), Some(low), Some(close), Some(volume)) =>
    Some({
      Config.openTime: Trade.Timestamp(timestamp),
      open_: Trade.Price(open_),
      high: Trade.Price(high),
      low: Trade.Price(low),
      close: Trade.Price(close),
      volume: Config.Volume(volume),
      closeTime: Trade.Timestamp(timestamp),
    })
  | _ => None
  }
}

let getCandles = async (
  t: t,
  ~symbol: Trade.symbol,
  ~interval: Config.interval,
  ~limit: Config.candleCount,
): result<array<Config.candlestick>, BotError.t> => {
  let Trade.Symbol(sym) = symbol
  let Config.Interval(ivl) = interval
  let Config.CandleCount(lim) = limit
  let unifiedSymbol = toUnifiedSymbol(symbol)

  try {
    await CcxtBindings.loadMarkets(t.exchange)
    let ohlcvRows = await CcxtBindings.fetchOHLCV(t.exchange, unifiedSymbol, ivl, None, lim)
    let candles = ohlcvRows->Array.filterMap(parseOhlcvRow)
    if candles->Array.length == 0 && ohlcvRows->Array.length > 0 {
      Error(BotError.MarketDataError(InvalidCandleData({message: "Could not parse any OHLCV rows"})))
    } else {
      Ok(candles)
    }
  } catch {
  | JsExn(jsExn) =>
    let msg = jsExn->JsExn.message->Option.getOr("Unknown CCXT error")
    Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: ivl, message: msg})))
  | _ =>
    Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: ivl, message: "Unknown CCXT error"})))
  }
}

let getCurrentPrice = async (
  t: t,
  symbol: Trade.symbol,
): result<Trade.price, BotError.t> => {
  let Trade.Symbol(sym) = symbol
  let unifiedSymbol = toUnifiedSymbol(symbol)

  try {
    await CcxtBindings.loadMarkets(t.exchange)
    let ticker = await CcxtBindings.fetchTicker(t.exchange, unifiedSymbol)
    switch ticker.last->Nullable.toOption {
    | Some(price) => Ok(Trade.Price(price))
    | None =>
      Error(BotError.MarketDataError(InvalidCandleData({message: "Ticker missing last price"})))
    }
  } catch {
  | JsExn(jsExn) =>
    let msg = jsExn->JsExn.message->Option.getOr("Unknown CCXT error")
    Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: "ticker", message: msg})))
  | _ =>
    Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: "ticker", message: "Unknown CCXT error"})))
  }
}
