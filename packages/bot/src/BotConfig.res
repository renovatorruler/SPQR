// Bot configuration (typed ReScript, no JSON)
// All values are explicit and domain-typed per RESCRIPT_MANIFESTO_LLM.MD

let config: Config.botConfig = {
  tradingMode: Config.Paper,
  exchange: {
    exchangeId: Config.Kraken,
    baseUrl: None,
    apiKey: None,
    apiSecret: None,
  },
  symbols: [
    Trade.Symbol("BTCUSD"),
    Trade.Symbol("ETHUSD"),
    Trade.Symbol("SOLUSD"),
  ],
  riskLimits: {
    maxPositionSize: Trade.Quantity(1000.0),
    maxOpenPositions: Config.MaxOpenPositions(3),
    maxDailyLoss: Position.Pnl(250.0),
  },
  qfl: {
    crackThreshold: Config.CrackPercent(3.0),
    baseFilter: {
      minBounces: Config.BounceCount(2),
      tolerance: Config.TolerancePercent(0.5),
      maxBaseDrift: Config.DriftPercent(1.0),
    },
    exitPolicy: {
      stopLoss: Config.StopLossPercent(5.0),
      takeProfit: Config.TakeProfitPercent(2.0),
      maxHold: Config.HoldCandles(16),
    },
    reentry: Config.ReentryOnce({cooldown: Config.CooldownCandles(32)}),
    regimeGate: {
      emaFast: Config.EmaPeriod(50),
      emaSlow: Config.EmaPeriod(200),
      emaSlopeLookback: Config.EmaSlopeLookback(20),
    },
    setupEvaluation:
      Config.Committee({
        members: [
          {
            provider: Config.OpenRouter,
            modelId: Config.LlmModelId("openai/gpt-5.3-codex"),
            apiKey: Config.LlmApiKey("OPENROUTER_API_KEY"),
            apiBase: Config.LlmBaseUrl("https://openrouter.ai/api/v1"),
            weight: Config.Weight(0.6),
            timeout: Config.TimeoutMs(15000),
          },
          {
            provider: Config.OpenRouter,
            modelId: Config.LlmModelId("anthropic/claude-3.5-sonnet"),
            apiKey: Config.LlmApiKey("OPENROUTER_API_KEY"),
            apiBase: Config.LlmBaseUrl("https://openrouter.ai/api/v1"),
            weight: Config.Weight(0.4),
            timeout: Config.TimeoutMs(15000),
          },
        ],
        rule: Config.WeightedMajority({minWeight: Config.Weight(0.6)}),
        minConfidence: Config.Confidence(0.6),
      }),
    lookbackCandles: Config.CandleCount(200),
  },
  llm: None,
  marketData: {
    source: Config.Ccxt({exchangeId: Config.ExchangeName("kraken")}),
    defaultInterval: Config.Interval("15m"),
  },
  engine: {
    pollIntervalMs: Config.PollIntervalMs(30000),
    closeOnShutdown: false,
  },
}

let load = (): result<Config.botConfig, BotError.t> => Ok(config)
