// Binance public API market data — no authentication required
// Fetches candles from /api/v3/klines and prices from /api/v3/ticker/price

type t = {
  config: Config.marketDataConfig,
  baseUrl: string,
}

let resolveBaseUrl = (source: Config.marketDataSource): string => {
  switch source {
  | BinancePublic => "https://api.binance.com"
  | BinanceUS => "https://api.binance.us"
  | CustomSource({baseUrl: Config.BaseUrl(url)}) => url
  }
}

let make = (config: Config.marketDataConfig): result<t, BotError.t> => {
  Ok({config, baseUrl: resolveBaseUrl(config.source)})
}

// Binance klines returns arrays: [openTime, open, high, low, close, volume, closeTime, ...]
let parseCandlestick = (json: JSON.t): option<Config.candlestick> => {
  json
  ->JSON.Decode.array
  ->Option.flatMap(arr => {
    switch (
      arr[0]->Option.flatMap(JSON.Decode.float),
      arr[1]->Option.flatMap(JSON.Decode.string)->Option.flatMap(Float.fromString),
      arr[2]->Option.flatMap(JSON.Decode.string)->Option.flatMap(Float.fromString),
      arr[3]->Option.flatMap(JSON.Decode.string)->Option.flatMap(Float.fromString),
      arr[4]->Option.flatMap(JSON.Decode.string)->Option.flatMap(Float.fromString),
      arr[5]->Option.flatMap(JSON.Decode.string)->Option.flatMap(Float.fromString),
      arr[6]->Option.flatMap(JSON.Decode.float),
    ) {
    | (
        Some(openTime),
        Some(open_),
        Some(high),
        Some(low),
        Some(close),
        Some(volume),
        Some(closeTime),
      ) =>
      Some({
        Config.openTime: Trade.Timestamp(openTime),
        open_: Trade.Price(open_),
        high: Trade.Price(high),
        low: Trade.Price(low),
        close: Trade.Price(close),
        volume: Config.Volume(volume),
        closeTime: Trade.Timestamp(closeTime),
      })
    | _ => None
    }
  })
}

@val external fetch: string => promise<'response> = "fetch"
@send external json: 'response => promise<JSON.t> = "json"
@get external ok: 'response => bool = "ok"
@get external statusText: 'response => string = "statusText"

let getCandles = async (
  t: t,
  ~symbol: Trade.symbol,
  ~interval: Config.interval,
  ~limit: Config.candleCount,
): result<array<Config.candlestick>, BotError.t> => {
  let Trade.Symbol(sym) = symbol
  let Config.Interval(ivl) = interval
  let Config.CandleCount(lim) = limit
  let url = `${t.baseUrl}/api/v3/klines?symbol=${sym}&interval=${ivl}&limit=${lim->Int.toString}`

  try {
    let response = await fetch(url)
    if !ok(response) {
      Error(
        BotError.MarketDataError(
          FetchFailed({symbol: sym, interval: ivl, message: statusText(response)}),
        ),
      )
    } else {
      let jsonData = await json(response)
      switch jsonData->JSON.Decode.array {
      | None =>
        Error(BotError.MarketDataError(InvalidCandleData({message: "Expected array response"})))
      | Some(arr) =>
        let candles = arr->Array.filterMap(parseCandlestick)
        if candles->Array.length == 0 && arr->Array.length > 0 {
          Error(
            BotError.MarketDataError(InvalidCandleData({message: "Could not parse any candles"})),
          )
        } else {
          Ok(candles)
        }
      }
    }
  } catch {
  | JsExn(jsExn) =>
    let msg = jsExn->JsExn.message->Option.getOr("Unknown fetch error")
    Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: ivl, message: msg})))
  | _ =>
    Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: ivl, message: "Unknown error"})))
  }
}

let getCurrentPrice = async (
  t: t,
  symbol: Trade.symbol,
): result<Trade.price, BotError.t> => {
  let Trade.Symbol(sym) = symbol
  let url = `${t.baseUrl}/api/v3/ticker/price?symbol=${sym}`

  try {
    let response = await fetch(url)
    if !ok(response) {
      Error(
        BotError.MarketDataError(
          FetchFailed({symbol: sym, interval: "ticker", message: statusText(response)}),
        ),
      )
    } else {
      let jsonData = await json(response)
      switch jsonData->JSON.Decode.object {
      | None =>
        Error(BotError.MarketDataError(InvalidCandleData({message: "Expected object response"})))
      | Some(obj) =>
        switch obj->Dict.get("price")->Option.flatMap(JSON.Decode.string)->Option.flatMap(Float.fromString) {
        | Some(price) => Ok(Trade.Price(price))
        | None =>
          Error(BotError.MarketDataError(InvalidCandleData({message: "Missing price field"})))
        }
      }
    }
  } catch {
  | JsExn(jsExn) =>
    let msg = jsExn->JsExn.message->Option.getOr("Unknown fetch error")
    Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: "ticker", message: msg})))
  | _ =>
    Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: "ticker", message: "Unknown error"})))
  }
}
