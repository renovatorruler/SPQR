# Bot Engine Implementation Plan

## Spec Summary

- **Strategy:** QFL (Quick Fingers Luc) — stop-loss model
- **Core idea:** Detect sideways channels, buy cracks below base, sell on bounce back. If base breaks → stop loss → wait for new channel.
- **LLM integration:** Both periodic regime analysis + per-setup evaluation. Claude API.
- **Loop:** Polling interval (configurable, default 30s)
- **Execution:** Fully automatic
- **State:** SQLite persistence (survives restarts)
- **Lifecycle:** Graceful — validate config, check exchange, run loop, shutdown with summary
- **Multi-symbol:** Loop through all symbols in config
- **Risk:** Hard stop when limits hit
- **Market data:** Configurable source (start with Binance public API for candles)
- **Future:** Fractal cascade model as alternative anti-martingale strategy

---

## Architecture Overview

```
Main.res (lifecycle)
  │
  ├─ BotConfig.res (load + validate config from JSON file)
  │
  ├─ MarketData.res (fetch candles from configurable source)
  │   └─ BinanceMarketData.res (Binance public API implementation)
  │
  ├─ QflStrategy.res (QFL base detection + signal generation)
  │   ├─ BaseDetector.res (find support levels from candle data)
  │   └─ StopLossManager.res (track stop losses, detect base breaks)
  │
  ├─ LlmEvaluator.res (Claude API for regime + setup evaluation)
  │
  ├─ RiskManager.res (enforce risk limits, hard stop)
  │
  ├─ BotLoop.res (main polling loop, orchestrates everything)
  │
  ├─ BotState.res (in-memory state + SQLite persistence)
  │   └─ Db.res (SQLite operations — trades, positions, bot state)
  │
  └─ PaperExchange.res (existing — enhanced with real market prices)
```

---

## Step 1: Extend Shared Types

**Files:** `packages/shared/src/Config.res`, `packages/shared/src/BotError.res`, `packages/shared/src/Trade.res`

### Config.res — add QFL + engine config types

```rescript
// New types to add:

// Candle data for market analysis
@unboxed type interval = Interval(string)  // "1m", "5m", "1h", "4h", "1d"

type candlestick = {
  openTime: Trade.timestamp,
  open: Trade.price,
  high: Trade.price,
  low: Trade.price,
  close: Trade.price,
  volume: float,
  closeTime: Trade.timestamp,
}

// QFL strategy config
@unboxed type crackPercent = CrackPercent(float)
@unboxed type stopLossPercent = StopLossPercent(float)
@unboxed type takeProfitPercent = TakeProfitPercent(float)
@unboxed type bounceCount = BounceCount(int)

type qflConfig = {
  crackThreshold: crackPercent,       // e.g., 3.0 = buy when 3% below base
  stopLossThreshold: stopLossPercent, // e.g., 5.0 = stop loss at 5% below entry
  takeProfitTarget: takeProfitPercent, // e.g., return to base = sell
  minBouncesForBase: bounceCount,     // e.g., 3 = need 3 bounces to confirm base
  lookbackCandles: int,               // how many candles to analyze for bases
}

// LLM config
@unboxed type llmApiKey = LlmApiKey(string)
@unboxed type llmModel = LlmModel(string)

type llmConfig = {
  apiKey: llmApiKey,
  model: llmModel,                      // e.g., "claude-sonnet-4-5-20250929"
  regimeCheckIntervalMs: int,           // how often to check market regime
  evaluateSetups: bool,                 // whether to LLM-evaluate individual setups
}

// Market data source config
type marketDataSource =
  | BinancePublic
  | Custom({baseUrl: baseUrl})

type marketDataConfig = {
  source: marketDataSource,
  defaultInterval: interval,
}

// Engine config
@unboxed type pollIntervalMs = PollIntervalMs(int)

type engineConfig = {
  pollIntervalMs: pollIntervalMs,       // default 30000
  closeOnShutdown: bool,
}

// Extend botConfig to include new fields
type botConfig = {
  tradingMode: tradingMode,
  exchange: exchangeConfig,
  symbols: array<Trade.symbol>,
  riskLimits: riskLimits,
  qfl: qflConfig,
  llm: llmConfig,
  marketData: marketDataConfig,
  engine: engineConfig,
}
```

### BotError.res — add new error domains

```rescript
// New error kinds to add:

type marketDataErrorKind =
  | FetchFailed({symbol: string, interval: string, message: string})
  | InvalidCandleData({message: string})
  | RateLimited({retryAfterMs: int})

type llmErrorKind =
  | ApiCallFailed({message: string})
  | InvalidResponse({message: string})
  | RateLimited({retryAfterMs: int})

type riskErrorKind =
  | MaxDailyLossReached({currentLoss: float, limit: float})
  | MaxOpenPositionsReached({current: int, limit: int})
  | MaxPositionSizeExceeded({requested: float, limit: float})

// Extend t:
type t =
  | ExchangeError(exchangeErrorKind)
  | ConfigError(configErrorKind)
  | StrategyError(strategyErrorKind)
  | MarketDataError(marketDataErrorKind)
  | LlmError(llmErrorKind)
  | RiskError(riskErrorKind)
```

---

## Step 2: Market Data Layer

**New files:** `packages/bot/src/MarketData.res`, `packages/bot/src/BinanceMarketData.res`

### MarketData.res — interface for fetching candle data

```rescript
// Module type for market data sources
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
```

### BinanceMarketData.res — Binance public API implementation

Fetches from `https://api.binance.com/api/v3/klines` (no auth needed).
Parses the JSON array response into `Config.candlestick` records.
Also implements `getCurrentPrice` via `/api/v3/ticker/price`.

---

## Step 3: QFL Strategy

**New files:** `packages/bot/src/BaseDetector.res`, `packages/bot/src/QflStrategy.res`

### BaseDetector.res — find support levels from candle data

Core algorithm:
1. Scan candle data for local minimums (price bounced up after touching this level)
2. Group nearby minimums into "base zones" (within a configurable tolerance, e.g., 0.5%)
3. Count bounces per zone — a zone with >= `minBouncesForBase` bounces is a confirmed base
4. Return array of detected bases sorted by strength (bounce count)

```rescript
type base = {
  priceLevel: Trade.price,      // the support level
  bounceCount: int,             // how many times price bounced here
  firstSeen: Trade.timestamp,   // when this base was first detected
  lastBounce: Trade.timestamp,  // most recent bounce
  strength: float,              // confidence score (bounces, recency, volume)
}

type baseDetectionResult =
  | NoBases
  | BasesFound({bases: array<base>})

let detectBases: (
  array<Config.candlestick>,
  ~minBounces: Config.bounceCount,
  ~tolerance: float,
) => baseDetectionResult
```

**User contribution opportunity:** The base detection algorithm is the core of the strategy. The exact definition of "local minimum" and "bounce" is a design choice that shapes everything.

### QflStrategy.res — QFL signal generation

Takes candle data + detected bases + current price → produces signals.

```rescript
type qflSignal =
  | CrackDetected({
      base: BaseDetector.base,
      currentPrice: Trade.price,
      crackPercent: float,
      symbol: Trade.symbol,
    })
  | BounceBack({
      entryPrice: Trade.price,
      currentPrice: Trade.price,
      base: BaseDetector.base,
      symbol: Trade.symbol,
    })
  | StopLossTriggered({
      entryPrice: Trade.price,
      currentPrice: Trade.price,
      lossPercent: float,
      symbol: Trade.symbol,
    })
  | NoSignal

// Main analysis function
let analyze: (
  ~candles: array<Config.candlestick>,
  ~currentPrice: Trade.price,
  ~symbol: Trade.symbol,
  ~config: Config.qflConfig,
  ~openPositions: array<Position.position>,
) => result<qflSignal, BotError.t>
```

Also update `Strategy.res` to accommodate the richer signal type.

---

## Step 4: LLM Evaluator

**New file:** `packages/bot/src/LlmEvaluator.res`

Two functions:

### assessRegime — periodic market mood check

```rescript
type marketRegime =
  | Ranging({confidence: float})
  | TrendingUp({confidence: float})
  | TrendingDown({confidence: float})
  | HighVolatility({confidence: float})
  | Unknown

let assessRegime: (
  ~candles: array<Config.candlestick>,
  ~config: Config.llmConfig,
) => promise<result<marketRegime, BotError.t>>
```

Calls Claude API with candle summary. Asks for regime classification + confidence.

### evaluateSetup — per-crack evaluation

```rescript
type setupEvaluation =
  | Go({reasoning: string})
  | Skip({reasoning: string})

let evaluateSetup: (
  ~crack: QflStrategy.qflSignal,
  ~candles: array<Config.candlestick>,
  ~regime: marketRegime,
  ~config: Config.llmConfig,
) => promise<result<setupEvaluation, BotError.t>>
```

Calls Claude API with the specific setup context. Gets go/no-go + reasoning.

**Implementation:** Use `fetch` to call `https://api.anthropic.com/v1/messages`. Parse response JSON. Structure the prompt with candle data summary, base info, regime context.

---

## Step 5: Risk Manager

**New file:** `packages/bot/src/RiskManager.res`

```rescript
type riskCheckResult =
  | Allowed
  | Blocked(BotError.t)

type t = {
  config: Config.riskLimits,
  mutable dailyPnl: Position.pnl,
  mutable openPositionCount: int,
  mutable halted: bool,
}

let make: Config.riskLimits => t

// Check if a new trade is allowed
let checkEntry: (
  t,
  ~qty: Trade.quantity,
  ~price: Trade.price,
) => riskCheckResult

// Update state after a trade
let recordTrade: (t, Trade.trade) => unit
let recordClose: (t, Position.pnl) => unit

// Hard stop check
let isHalted: t => bool
```

When any limit is hit, `halted` goes to `true` and bot stops entering new positions.

---

## Step 6: SQLite Persistence

**New files:** `packages/bot/src/Db.res`, `packages/bot/src/BotState.res`

### Db.res — SQLite operations

**New dependency:** `better-sqlite3` (already in PLAN.md)

Tables:
- `trades` — all executed trades
- `positions` — all positions (open and closed)
- `bot_state` — bot runtime state (last regime, halted status, etc.)
- `bases` — detected base levels per symbol

```rescript
type t  // opaque DB handle

let open_: string => result<t, BotError.t>
let close: t => unit
let migrate: t => result<unit, BotError.t>  // create tables if not exist

// Trade operations
let insertTrade: (t, Trade.trade) => result<unit, BotError.t>
let getTradesBySymbol: (t, Trade.symbol) => result<array<Trade.trade>, BotError.t>

// Position operations
let insertPosition: (t, Position.position) => result<unit, BotError.t>
let updatePosition: (t, Position.position) => result<unit, BotError.t>
let getOpenPositions: t => result<array<Position.position>, BotError.t>

// Bot state
let saveBotState: (t, botStateRecord) => result<unit, BotError.t>
let loadBotState: t => result<option<botStateRecord>, BotError.t>

// Base levels
let saveBases: (t, Trade.symbol, array<BaseDetector.base>) => result<unit, BotError.t>
let loadBases: (t, Trade.symbol) => result<array<BaseDetector.base>, BotError.t>
```

### BotState.res — in-memory state backed by SQLite

```rescript
type t = {
  db: Db.t,
  riskManager: RiskManager.t,
  mutable regime: LlmEvaluator.marketRegime,
  mutable lastRegimeCheck: Trade.timestamp,
  mutable basesBySymbol: Dict.t<array<BaseDetector.base>>,
}

let make: (Db.t, Config.riskLimits) => t
let restore: Db.t => result<t, BotError.t>  // restore from SQLite on restart
let persist: t => result<unit, BotError.t>   // save current state to SQLite
```

---

## Step 7: Bot Loop

**New file:** `packages/bot/src/BotLoop.res`

The main orchestration loop. Runs every `pollIntervalMs`.

```
Each tick:
  1. For each symbol in config.symbols:
     a. Fetch candles from MarketData
     b. Get current price
     c. Run BaseDetector on candles → find bases
     d. Run QflStrategy.analyze with bases + price + open positions
     e. If signal is CrackDetected:
        - Check if regime check is stale → if so, call LlmEvaluator.assessRegime
        - If config.llm.evaluateSetups → call LlmEvaluator.evaluateSetup
        - If LLM says Go (or LLM disabled) → check RiskManager.checkEntry
        - If Allowed → place buy order via Exchange
        - Persist trade + position to SQLite
     f. If signal is BounceBack:
        - Place sell order (take profit)
        - Close position, record PnL
     g. If signal is StopLossTriggered:
        - Place sell order (stop loss)
        - Close position, record loss
        - Log: "Base broken, waiting for new channel"
     h. If NoSignal → continue
  2. Check if RiskManager.isHalted → if yes, log and stop loop
  3. Sleep for pollIntervalMs
```

```rescript
type loopConfig = {
  exchange: PaperExchange.t,  // or any Exchange.S implementation
  marketData: BinanceMarketData.t,  // or any MarketData.S
  state: BotState.t,
  config: Config.botConfig,
}

let runTick: loopConfig => promise<result<unit, BotError.t>>
let startLoop: loopConfig => promise<unit>
let stopLoop: unit => unit  // sets a flag to stop after current tick
```

---

## Step 8: Enhanced Main.res — Graceful Lifecycle

**Modified file:** `packages/bot/src/Main.res`

```
Startup:
  1. Load config from file (BotConfig.loadFromFile)
  2. Validate config
  3. Open SQLite database, run migrations
  4. Restore bot state from DB (or create fresh)
  5. Initialize exchange (PaperExchange.make)
  6. Initialize market data source (BinanceMarketData.make)
  7. Test exchange connectivity (getBalance)
  8. Test market data connectivity (fetch 1 candle)
  9. Log startup summary (config, balance, open positions)
  10. Start bot loop

Shutdown (SIGINT):
  1. Stop loop after current tick
  2. Persist final bot state to SQLite
  3. Log shutdown summary:
     - Total trades made
     - Open positions
     - Current P&L
     - Final balance
  4. Close SQLite connection
  5. Exit
```

---

## Step 9: Update PaperExchange with Real Market Prices

**Modified file:** `packages/bot/src/PaperExchange.res`

Currently `getPrice` returns fixed 100.0. Update it to accept a price feed callback
or integrate with MarketData so paper trades use real prices from Binance.

Option: Add a `setCurrentPrices` function that the bot loop calls each tick with real
prices, so PaperExchange fills orders at realistic prices.

---

## Step 10: Update BotConfig Decoder

**Modified file:** `packages/bot/src/BotConfig.res`

- Add decoders for new config sections: `qfl`, `llm`, `marketData`, `engine`
- Implement `loadFromFile` using Node.js `fs` (via ReScript external binding)
- Add a sample `config.json` to the repo (with `.gitignore`d secrets)

---

## Step 11: Add Dependencies

**Modified files:** `packages/bot/package.json`, root `package.json`

New dependencies:
- `better-sqlite3` — SQLite driver for Node.js
- No new deps for Claude API (use native `fetch`)
- No new deps for Binance API (use native `fetch`)

Dev dependencies:
- `@types/better-sqlite3` (if we need type info for bindings)

---

## Implementation Order

| # | What | Files | Depends on |
|---|------|-------|-----------|
| 1 | Extend shared types (Config, BotError) | shared/src/Config.res, shared/src/BotError.res | nothing |
| 2 | SQLite layer (Db.res) | bot/src/Db.res | step 1, better-sqlite3 |
| 3 | Market data interface + Binance impl | bot/src/MarketData.res, bot/src/BinanceMarketData.res | step 1 |
| 4 | Base detection algorithm | bot/src/BaseDetector.res | step 1 |
| 5 | QFL strategy | bot/src/QflStrategy.res | steps 1, 4 |
| 6 | LLM evaluator | bot/src/LlmEvaluator.res | step 1 |
| 7 | Risk manager | bot/src/RiskManager.res | step 1 |
| 8 | Bot state (in-memory + SQLite) | bot/src/BotState.res | steps 2, 6, 7 |
| 9 | Update BotConfig decoder | bot/src/BotConfig.res | step 1 |
| 10 | Update PaperExchange with real prices | bot/src/PaperExchange.res | step 3 |
| 11 | Bot loop orchestration | bot/src/BotLoop.res | steps 3-8 |
| 12 | Main lifecycle (startup + shutdown) | bot/src/Main.res | steps 9, 11 |
| 13 | Add dependencies + sample config | package.json files, config.example.json | step 2 |
| 14 | Build + verify compilation | all | all |

---

## User Contribution Points

These are places where your input shapes the strategy's behavior — the "brain" of the bot:

1. **BaseDetector.res — `detectBases` function** (~10 lines): How exactly do you define a "local minimum" and a "bounce"? This is the core pattern recognition.

2. **QflStrategy.res — crack threshold logic** (~5 lines): When a crack is detected, how should we calculate position size? Fixed from config, or scaled by crack depth?

3. **LlmEvaluator.res — prompt engineering** (~15 lines): The prompt template sent to Claude for regime analysis and setup evaluation. This determines how well the LLM understands what you're looking for.

---

## Sample Config (config.example.json)

```json
{
  "tradingMode": "paper",
  "exchange": {
    "exchangeId": "paper"
  },
  "symbols": ["BTCUSDT", "ETHUSDT"],
  "riskLimits": {
    "maxPositionSize": 1000.0,
    "maxOpenPositions": 5,
    "maxDailyLoss": 500.0
  },
  "qfl": {
    "crackThreshold": 3.0,
    "stopLossThreshold": 5.0,
    "takeProfitTarget": 0.0,
    "minBouncesForBase": 3,
    "lookbackCandles": 200
  },
  "llm": {
    "apiKey": "sk-ant-...",
    "model": "claude-sonnet-4-5-20250929",
    "regimeCheckIntervalMs": 1800000,
    "evaluateSetups": true
  },
  "marketData": {
    "source": "binance",
    "defaultInterval": "1h"
  },
  "engine": {
    "pollIntervalMs": 30000,
    "closeOnShutdown": false
  }
}
```
