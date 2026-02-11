# Project Scope

## Goal
Build a trading bot using a QFL base scanner strategy, modified to avoid long, stagnant drawdowns during bear markets. The strategy will run for the next few months with an assumption that the market may go down significantly.

## Key Concern
Traditional QFL can get stuck holding bad trades for months/years when the market changes channels (e.g., long drift down). We need a solution that prevents prolonged capital lock-up in bear regimes.

## Strategy Focus (Current Phase)
- Focus on strategy design and mitigation for QFL drawdown/lock-up risks.
- Timeframes to scan: 15m, 1h, 4h, up to 1d max; initial implementation on 15m.
- Strategy should be spot-only in practice, using cash as the “short,” but allow future short exposure if needed.
- Core mitigations: regime gate, hard stop, time stop, re-entry limits, and cooldowns.

## Preferences & Constraints
- Primary behavior: QFL-style strategy, adjusted for bear-market risk.
- Short exposure: allowed, but preference is to stay spot-only by holding cash as the “short” and going long only when conditions are favorable.
- Stablecoin parking is allowed, but all activity must be active trading (no passive yield).
- Bot may pause trading to protect capital.
- Configuration must be typed ReScript only (no JSON), honoring `RESCRIPT_MANIFESTO_LLM.MD`.
- Avoid direct primitive usage in domain types (e.g., `int` must be wrapped in @unboxed types).

## Exchanges & Instruments
- Exchanges: Kraken and any DEX.
- Interest in Jupiter (Solana DEX aggregator) if viable.
- Planning to use CCXT for exchange access.

## LLM Committee Requirement
- Use GPT-5.3 Codex Model to analyze trade setups.
- Run a committee of the latest LLM models and decide entries based on their votes.
- Committee decision uses weighted voting + confidence thresholds.
- Committee should use OpenRouter for model access.

## Open Questions
- What library or approach should be used for Jupiter trading, and whether CCXT supports it.
- Backtesting framework design and integration plan.
- LiftKit will be used for the interface (dashboard/UI).

## Related Docs
- `BACKTEST_PLAN.md`
- `DASHBOARD_LIFTKIT_PLAN.md`
