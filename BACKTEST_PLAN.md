# Backtesting Framework — Design Plan

## Goals
- Deterministic, reproducible backtests for QFL and future strategies.
- Shared types between bot and dashboard (results + metrics).
- No JSON config; all typed ReScript values.
- Compatible with RESCRIPT_MANIFESTO_LLM.MD.

## Core Modules

### Shared Types (packages/shared/src/Backtest.res)
- `backtestConfig` (window, interval, initial balance, fees, slippage)
- `result` (trades, equity curve, metrics)
- All domain values are @unboxed types.

### Data Adapters (packages/bot/src/BacktestData*.res)
- `BacktestDataSource.res` (module type):
  - `loadCandles: (~symbol, ~window, ~interval) => result<array<Config.candlestick>, BotError.t>`
- Implementations:
  - `CsvDataSource.res` (CSV files per symbol)
  - `CcxtDataSource.res` (historical via CCXT where available)

### Simulation Engine (packages/bot/src/BacktestRunner.res)
- Deterministic event loop over candles.
- Feeds rolling window of candles into strategy per symbol.
- Applies fee/slippage models to simulated fills.
- Tracks positions, equity curve, and realized PnL.

### Strategy Adapter (packages/bot/src/BacktestStrategy.res)
- Module type to adapt QFL signals into simulated orders.
- Keeps position state and enforces time stop and cooldown policies.

### Metrics (packages/bot/src/BacktestMetrics.res)
- Computes win rate, total return, max drawdown, and trade count.

## Execution Flow
1) Load candle data for each symbol in window.
2) For each candle tick:
   - Update rolling window.
   - Run strategy analyze.
   - Simulate orders (fees/slippage).
   - Record trades + equity curve point.
3) At end, compute metrics and output `Backtest.result`.

## Determinism
- No network calls inside the runner.
- All randomness disabled; explicit ordering by timestamp.

## Output
- `Backtest.result` stored to SQLite for dashboard inspection.
- Dashboard uses LiftKit for visualization (equity curve + trade list).
