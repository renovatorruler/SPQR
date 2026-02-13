open Vitest

// Tests for LlmShared — the shared types, prompt builders, and config converters
// that underpin the LLM module functor.

describe("LlmShared.regimeToLabel", () => {
  it("maps Ranging to RANGING", () => {
    LlmShared.regimeToLabel(Ranging({confidence: Config.Confidence(0.7)}))->expect->toBe("RANGING")
  })

  it("maps TrendingUp to TRENDING UP", () => {
    LlmShared.regimeToLabel(TrendingUp({confidence: Config.Confidence(0.8)}))->expect->toBe(
      "TRENDING UP",
    )
  })

  it("maps TrendingDown to TRENDING DOWN", () => {
    LlmShared.regimeToLabel(TrendingDown({confidence: Config.Confidence(0.6)}))->expect->toBe(
      "TRENDING DOWN",
    )
  })

  it("maps HighVolatility to HIGH VOLATILITY", () => {
    LlmShared.regimeToLabel(HighVolatility({confidence: Config.Confidence(0.9)}))->expect->toBe(
      "HIGH VOLATILITY",
    )
  })

  it("maps Unknown to UNKNOWN", () => {
    LlmShared.regimeToLabel(Unknown)->expect->toBe("UNKNOWN")
  })
})

describe("LlmShared.configFromMember", () => {
  it("extracts modelId, apiKey, baseUrl from llmMember", () => {
    let member: Config.llmMember = {
      provider: Config.OpenRouter,
      modelId: Config.LlmModelId("openai/gpt-4"),
      apiKey: Config.LlmApiKey("sk-test-key"),
      apiBase: Config.LlmBaseUrl("https://openrouter.ai/api/v1"),
      weight: Config.Weight(0.6),
      timeout: Config.TimeoutMs(15000),
    }
    let config = LlmShared.configFromMember(member)
    expect(config.modelId)->toBe("openai/gpt-4")
    expect(config.baseUrl)->toBe("https://openrouter.ai/api/v1")
    let Config.TimeoutMs(ms) = config.timeout
    expect(ms)->toBe(15000)
  })

  it("preserves apiKey wrapper", () => {
    let member: Config.llmMember = {
      provider: Config.Anthropic,
      modelId: Config.LlmModelId("claude-3.5"),
      apiKey: Config.LlmApiKey("my-api-key"),
      apiBase: Config.LlmBaseUrl("https://api.anthropic.com/v1/messages"),
      weight: Config.Weight(1.0),
      timeout: Config.TimeoutMs(30000),
    }
    let config = LlmShared.configFromMember(member)
    let Config.LlmApiKey(key) = config.apiKey
    expect(key)->toBe("my-api-key")
  })
})

describe("LlmShared.configFromLlmConfig", () => {
  it("extracts modelId from LlmModel and sets Anthropic defaults", () => {
    let llmConfig: Config.llmConfig = {
      apiKey: Config.LlmApiKey("ant-key"),
      model: Config.LlmModel("claude-3-sonnet"),
      regimeCheckIntervalMs: Config.IntervalMs(60000),
      evaluateSetups: true,
    }
    let config = LlmShared.configFromLlmConfig(llmConfig)
    expect(config.modelId)->toBe("claude-3-sonnet")
    expect(config.baseUrl)->toBe("https://api.anthropic.com/v1/messages")
    let Config.TimeoutMs(ms) = config.timeout
    expect(ms)->toBe(30000)
    let Config.LlmApiKey(key) = config.apiKey
    expect(key)->toBe("ant-key")
  })
})

describe("LlmShared.buildRegimeUserPrompt", () => {
  it("includes candle data in prompt", () => {
    let candles: array<Config.candlestick> = [
      {
        openTime: Trade.Timestamp(1000.0),
        open_: Trade.Price(100.0),
        high: Trade.Price(110.0),
        low: Trade.Price(90.0),
        close: Trade.Price(105.0),
        volume: Config.Volume(5000.0),
        closeTime: Trade.Timestamp(1060.0),
      },
    ]
    let prompt = LlmShared.buildRegimeUserPrompt(~candles)
    // Should contain the candle data
    expect(prompt->String.includes("O:100.00"))->toBe(true)
    expect(prompt->String.includes("H:110.00"))->toBe(true)
    expect(prompt->String.includes("V:5000"))->toBe(true)
    // Should contain the instruction
    expect(prompt->String.includes("REGIME:"))->toBe(true)
  })
})

describe("LlmShared.buildSetupUserPrompt", () => {
  it("includes symbol, base, price, crack %, regime, and candle data", () => {
    let candles: array<Config.candlestick> = [
      {
        openTime: Trade.Timestamp(1000.0),
        open_: Trade.Price(100.0),
        high: Trade.Price(110.0),
        low: Trade.Price(90.0),
        close: Trade.Price(105.0),
        volume: Config.Volume(5000.0),
        closeTime: Trade.Timestamp(1060.0),
      },
    ]
    let base: BaseDetector.base = {
      priceLevel: Trade.Price(100.0),
      bounceCount: Config.BounceCount(3),
      firstSeen: Trade.Timestamp(900.0),
      lastBounce: Trade.Timestamp(950.0),
      minLevel: Trade.Price(99.0),
      maxLevel: Trade.Price(101.0),
    }
    let prompt = LlmShared.buildSetupUserPrompt(
      ~symbol=Trade.Symbol("BTCUSD"),
      ~base,
      ~currentPrice=Trade.Price(95.0),
      ~crackPercent=Config.CrackPercent(5.0),
      ~regime=LlmShared.Ranging({confidence: Config.Confidence(0.7)}),
      ~candles,
    )
    expect(prompt->String.includes("BTCUSD"))->toBe(true)
    expect(prompt->String.includes("95.00"))->toBe(true)
    expect(prompt->String.includes("100.00"))->toBe(true)
    expect(prompt->String.includes("3 bounces"))->toBe(true)
    expect(prompt->String.includes("5.0%"))->toBe(true)
    expect(prompt->String.includes("RANGING"))->toBe(true)
    expect(prompt->String.includes("GO or SKIP"))->toBe(true)
  })
})
