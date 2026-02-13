open Vitest

// Pure logic tests for StrategyConfigPanel.res
// Tests config-to-display-string formatters — no DOM needed

describe("StrategyConfigPanel.reentryToString", () => {
  it("returns 'No re-entry' for NoReentry", () => {
    StrategyConfigPanel.reentryToString(Config.NoReentry)->expect->toBe("No re-entry")
  })

  it("formats ReentryOnce with cooldown candles", () => {
    StrategyConfigPanel.reentryToString(
      Config.ReentryOnce({cooldown: Config.CooldownCandles(5)}),
    )->expect->toBe("Once after 5 candles")
  })

  it("handles zero cooldown", () => {
    StrategyConfigPanel.reentryToString(
      Config.ReentryOnce({cooldown: Config.CooldownCandles(0)}),
    )->expect->toBe("Once after 0 candles")
  })

  it("handles large cooldown", () => {
    StrategyConfigPanel.reentryToString(
      Config.ReentryOnce({cooldown: Config.CooldownCandles(100)}),
    )->expect->toBe("Once after 100 candles")
  })
})

describe("StrategyConfigPanel.setupEvalToString", () => {
  it("returns 'Disabled' for Disabled", () => {
    StrategyConfigPanel.setupEvalToString(Config.Disabled)->expect->toBe("Disabled")
  })

  it("returns 'Committee enabled' for Committee", () => {
    let committee: Config.committeeConfig = {
      members: [],
      rule: SimpleMajority,
      minConfidence: Config.Confidence(0.7),
    }
    StrategyConfigPanel.setupEvalToString(Config.Committee(committee))->expect->toBe(
      "Committee enabled",
    )
  })
})
