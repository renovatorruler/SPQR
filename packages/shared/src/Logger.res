// Structured JSON logger (Decision #8)
// Writes to stdout. Dashboard can read from SQLite.

// Variants over strings (Manifesto Principle 2)
type level =
  | Debug
  | Info
  | Trade
  | Error

let levelToString = (level: level): string => {
  switch level {
  | Debug => "DEBUG"
  | Info => "INFO"
  | Trade => "TRADE"
  | Error => "ERROR"
  }
}

type logEntry = {
  level: level,
  message: string,
  timestamp: Trade.timestamp,
  data: option<JSON.t>,
}

let now = (): Trade.timestamp => {
  Trade.Timestamp(Date.now())
}

let log = (~level: level, ~message: string, ~data: option<JSON.t>=?, ()): unit => {
  let entry = {
    level,
    message,
    timestamp: now(),
    data,
  }
  let Trade.Timestamp(ts) = entry.timestamp
  let json = Dict.make()
  json->Dict.set("level", entry.level->levelToString->JSON.Encode.string)
  json->Dict.set("message", entry.message->JSON.Encode.string)
  json->Dict.set("timestamp", ts->JSON.Encode.float)
  entry.data->Option.forEach(d => json->Dict.set("data", d))
  Console.log(json->JSON.Encode.object->JSON.stringify)
}

let debug = (~data=?, message: string): unit => {
  log(~level=Debug, ~message, ~data?, ())
}

let info = (~data=?, message: string): unit => {
  log(~level=Info, ~message, ~data?, ())
}

let trade = (~data=?, message: string): unit => {
  log(~level=Trade, ~message, ~data?, ())
}

let error = (~data=?, message: string): unit => {
  log(~level=Error, ~message, ~data?, ())
}
