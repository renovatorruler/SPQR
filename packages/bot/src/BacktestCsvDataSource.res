// CSV backtest data source
// Expected header: timestamp,open,high,low,close,volume

@module("node:fs") external readFileSync: (string, string) => string = "readFileSync"

type t = {paths: Dict.t<string>}

let make = (~paths: Dict.t<string>): t => ({paths: paths})

let parseFloat = (s: string): option<float> => {
  switch Float.parseFloat(s) {
  | value when Float.isNaN(value) => None
  | value => Some(value)
  }
}

let parseRow = (line: string): option<Config.candlestick> => {
  let parts = line->String.split(",")
  switch (parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]) {
  | (Some(ts), Some(o), Some(h), Some(l), Some(c), Some(v)) =>
    switch (parseFloat(ts), parseFloat(o), parseFloat(h), parseFloat(l), parseFloat(c), parseFloat(v)) {
    | (Some(tsf), Some(of_), Some(hf), Some(lf), Some(cf), Some(vf)) =>
      Some({
        Config.openTime: Trade.Timestamp(tsf),
        open_: Trade.Price(of_),
        high: Trade.Price(hf),
        low: Trade.Price(lf),
        close: Trade.Price(cf),
        volume: Config.Volume(vf),
        closeTime: Trade.Timestamp(tsf),
      })
    | _ => None
    }
  | _ => None
  }
}

let loadCandles = (
  t: t,
  ~symbol: Trade.symbol,
  ~window: Backtest.backtestWindow,
  ~interval: Config.interval,
): result<array<Config.candlestick>, BotError.t> => {
  let Trade.Symbol(sym) = symbol
  let _ = interval
  let pathOpt = t.paths->Dict.get(sym)

  switch pathOpt {
  | None =>
    Error(
      BotError.MarketDataError(
        FetchFailed({symbol: sym, interval: "", message: "CSV path not found for symbol"}),
      ),
    )
  | Some(path) =>
    let {start, end_} = window
    let Trade.Timestamp(startTs) = start
    let Trade.Timestamp(endTs) = end_

    try {
      let raw = readFileSync(path, "utf8")
      let lines = raw->String.split("\n")
      let rows =
        lines->Array.filter(line =>
          line->String.length > 0 &&
          !(line->String.toLowerCase->String.startsWith("timestamp"))
        )
      let data = rows->Array.filterMap(parseRow)
      let filtered = data->Array.filter(c => {
        let Trade.Timestamp(ts) = c.openTime
        ts >= startTs && ts <= endTs
      })
      Ok(filtered)
    } catch {
    | JsExn(jsExn) =>
      let msg = jsExn->JsExn.message->Option.getOr("Unknown error")
      Error(BotError.MarketDataError(FetchFailed({symbol: sym, interval: "", message: msg})))
    | _ =>
      Error(
        BotError.MarketDataError(
          FetchFailed({symbol: sym, interval: "", message: "Unknown CSV error"}),
        ),
      )
    }
  }
}
