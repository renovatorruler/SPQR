// CCXT exchange bindings — typed externals
// Uses ccxtHelper.mjs for dynamic exchange construction (manifesto-compliant: no %raw)

type exchange

type ticker = {last: Nullable.t<float>}

// Create exchange instance from exchange ID string (e.g. "kraken", "binance", "coinbase")
@module("./ccxtHelper.mjs")
external createExchange: string => exchange = "createExchange"

// Load exchange markets (must be called before fetchOHLCV/fetchTicker)
@send
external loadMarkets: exchange => promise<unit> = "loadMarkets"

// Fetch OHLCV candle data
// Returns array of arrays: [[timestamp, open, high, low, close, volume], ...]
// `since` is option<float> — None compiles to undefined (required by Kraken; null causes errors)
@send
external fetchOHLCV: (
  exchange,
  string,
  string,
  option<float>,
  int,
) => promise<array<array<float>>> = "fetchOHLCV"

// Fetch ticker with last price
@send
external fetchTicker: (exchange, string) => promise<ticker> = "fetchTicker"
