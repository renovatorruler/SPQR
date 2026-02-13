open Vitest

describe("BotError.toString", () => {
  describe("ExchangeError", () => {
    it("formats ConnectionFailed", () => {
      let err = BotError.ExchangeError(
        ConnectionFailed({url: "https://api.binance.com", message: "timeout"}),
      )
      expect(BotError.toString(err))->toBe(
        "Exchange connection failed (https://api.binance.com): timeout",
      )
    })

    it("formats AuthenticationFailed", () => {
      let err = BotError.ExchangeError(AuthenticationFailed)
      expect(BotError.toString(err))->toBe("Exchange authentication failed")
    })

    it("formats RateLimited", () => {
      let err = BotError.ExchangeError(RateLimited({retryAfterMs: 5000}))
      expect(BotError.toString(err))->toContainString("5000")
    })

    it("formats InsufficientBalance", () => {
      let err = BotError.ExchangeError(InsufficientBalance({available: 50.0, required: 100.0}))
      expect(BotError.toString(err))->toContainString("50")
      expect(BotError.toString(err))->toContainString("100")
    })

    it("formats OrderRejected", () => {
      let err = BotError.ExchangeError(OrderRejected({reason: "invalid symbol"}))
      expect(BotError.toString(err))->toContainString("invalid symbol")
    })
  })

  describe("ConfigError", () => {
    it("formats FileNotFound", () => {
      let err = BotError.ConfigError(FileNotFound({path: "/etc/config.json"}))
      expect(BotError.toString(err))->toContainString("/etc/config.json")
    })

    it("formats ParseFailed", () => {
      let err = BotError.ConfigError(ParseFailed({message: "unexpected token"}))
      expect(BotError.toString(err))->toContainString("unexpected token")
    })

    it("formats MissingField", () => {
      let err = BotError.ConfigError(MissingField({fieldName: "exchange.apiKey"}))
      expect(BotError.toString(err))->toContainString("exchange.apiKey")
    })

    it("formats InvalidValue", () => {
      let err = BotError.ConfigError(
        InvalidValue({fieldName: "mode", given: "test", expected: "paper | live"}),
      )
      expect(BotError.toString(err))->toContainString("mode")
      expect(BotError.toString(err))->toContainString("test")
    })
  })

  describe("StrategyError", () => {
    it("formats InsufficientData", () => {
      let err = BotError.StrategyError(InsufficientData({required: 20, available: 5}))
      expect(BotError.toString(err))->toContainString("20")
      expect(BotError.toString(err))->toContainString("5")
    })

    it("formats InvalidSignal", () => {
      let err = BotError.StrategyError(InvalidSignal({message: "bad signal"}))
      expect(BotError.toString(err))->toContainString("bad signal")
    })
  })

  describe("MarketDataError", () => {
    it("formats FetchFailed", () => {
      let err = BotError.MarketDataError(
        FetchFailed({symbol: "BTCUSDT", interval: "1h", message: "timeout"}),
      )
      expect(BotError.toString(err))->toContainString("BTCUSDT")
      expect(BotError.toString(err))->toContainString("1h")
    })

    it("formats InvalidCandleData", () => {
      let err = BotError.MarketDataError(InvalidCandleData({message: "bad format"}))
      expect(BotError.toString(err))->toContainString("bad format")
    })
  })

  describe("LlmError", () => {
    it("formats ApiCallFailed", () => {
      let err = BotError.LlmError(ApiCallFailed({message: "401 Unauthorized"}))
      expect(BotError.toString(err))->toContainString("401 Unauthorized")
    })
  })

  describe("RiskError", () => {
    it("formats MaxDailyLossReached", () => {
      let err = BotError.RiskError(MaxDailyLossReached({currentLoss: 500.0, limit: 200.0}))
      expect(BotError.toString(err))->toContainString("500")
      expect(BotError.toString(err))->toContainString("200")
    })

    it("formats MaxOpenPositionsReached", () => {
      let err = BotError.RiskError(
        MaxOpenPositionsReached({
          current: Config.OpenPositionsCount(5),
          limit: Config.MaxOpenPositions(3),
        }),
      )
      expect(BotError.toString(err))->toContainString("5")
      expect(BotError.toString(err))->toContainString("3")
    })

    it("formats MaxPositionSizeExceeded", () => {
      let err = BotError.RiskError(MaxPositionSizeExceeded({requested: 10000.0, limit: 5000.0}))
      expect(BotError.toString(err))->toContainString("10000")
      expect(BotError.toString(err))->toContainString("5000")
    })
  })

  describe("EngineError", () => {
    it("formats AlreadyRunning", () => {
      let err = BotError.EngineError(AlreadyRunning)
      expect(BotError.toString(err))->toBe("Engine is already running")
    })

    it("formats NotRunning", () => {
      let err = BotError.EngineError(NotRunning)
      expect(BotError.toString(err))->toBe("Engine is not running")
    })

    it("formats InitializationFailed", () => {
      let err = BotError.EngineError(InitializationFailed({message: "no config"}))
      expect(BotError.toString(err))->toContainString("no config")
    })

    it("formats TickFailed", () => {
      let err = BotError.EngineError(TickFailed({symbol: "ETHUSDT", message: "fetch error"}))
      expect(BotError.toString(err))->toContainString("ETHUSDT")
    })
  })
})
