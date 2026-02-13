open Vitest

describe("BotConfig", () => {
  it("loads typed config", () => {
    switch BotConfig.load() {
    | Ok(cfg) =>
      switch cfg.tradingMode {
      | Config.Paper => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
      switch cfg.exchange.exchangeId {
      | Config.Kraken => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
      expect(cfg.symbols->Array.length)->toBeGreaterThan(0)
      let Config.CrackPercent(_) = cfg.qfl.crackThreshold
      expect(true)->toBe(true) // crackThreshold is defined (type check)
      switch cfg.qfl.setupEvaluation {
      | Config.Committee(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    | Error(_) => expect(true)->toBe(false)
    }
  })
})
