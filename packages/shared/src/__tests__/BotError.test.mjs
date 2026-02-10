import { describe, it, expect } from "vitest";
import * as BotError from "../BotError.res.mjs";

describe("BotError.toString", () => {
  describe("ExchangeError", () => {
    it("formats ConnectionFailed", () => {
      const err = { TAG: "ExchangeError", _0: { TAG: "ConnectionFailed", url: "https://api.binance.com", message: "timeout" } };
      expect(BotError.toString(err)).toBe("Exchange connection failed (https://api.binance.com): timeout");
    });

    it("formats AuthenticationFailed", () => {
      const err = { TAG: "ExchangeError", _0: "AuthenticationFailed" };
      expect(BotError.toString(err)).toBe("Exchange authentication failed");
    });

    it("formats RateLimited", () => {
      const err = { TAG: "ExchangeError", _0: { TAG: "RateLimited", retryAfterMs: 5000 } };
      expect(BotError.toString(err)).toContain("5000");
    });

    it("formats InsufficientBalance", () => {
      const err = { TAG: "ExchangeError", _0: { TAG: "InsufficientBalance", available: 50.0, required: 100.0 } };
      expect(BotError.toString(err)).toContain("50");
      expect(BotError.toString(err)).toContain("100");
    });

    it("formats OrderRejected", () => {
      const err = { TAG: "ExchangeError", _0: { TAG: "OrderRejected", reason: "invalid symbol" } };
      expect(BotError.toString(err)).toContain("invalid symbol");
    });
  });

  describe("ConfigError", () => {
    it("formats FileNotFound", () => {
      const err = { TAG: "ConfigError", _0: { TAG: "FileNotFound", path: "/etc/config.json" } };
      expect(BotError.toString(err)).toContain("/etc/config.json");
    });

    it("formats ParseFailed", () => {
      const err = { TAG: "ConfigError", _0: { TAG: "ParseFailed", message: "unexpected token" } };
      expect(BotError.toString(err)).toContain("unexpected token");
    });

    it("formats MissingField", () => {
      const err = { TAG: "ConfigError", _0: { TAG: "MissingField", fieldName: "exchange.apiKey" } };
      expect(BotError.toString(err)).toContain("exchange.apiKey");
    });

    it("formats InvalidValue", () => {
      const err = { TAG: "ConfigError", _0: { TAG: "InvalidValue", fieldName: "mode", given: "test", expected: "paper | live" } };
      expect(BotError.toString(err)).toContain("mode");
      expect(BotError.toString(err)).toContain("test");
    });
  });

  describe("StrategyError", () => {
    it("formats InsufficientData", () => {
      const err = { TAG: "StrategyError", _0: { TAG: "InsufficientData", required: 20, available: 5 } };
      expect(BotError.toString(err)).toContain("20");
      expect(BotError.toString(err)).toContain("5");
    });

    it("formats InvalidSignal", () => {
      const err = { TAG: "StrategyError", _0: { TAG: "InvalidSignal", message: "bad signal" } };
      expect(BotError.toString(err)).toContain("bad signal");
    });
  });

  describe("MarketDataError", () => {
    it("formats FetchFailed", () => {
      const err = { TAG: "MarketDataError", _0: { TAG: "FetchFailed", symbol: "BTCUSDT", interval: "1h", message: "timeout" } };
      expect(BotError.toString(err)).toContain("BTCUSDT");
      expect(BotError.toString(err)).toContain("1h");
    });

    it("formats InvalidCandleData", () => {
      const err = { TAG: "MarketDataError", _0: { TAG: "InvalidCandleData", message: "bad format" } };
      expect(BotError.toString(err)).toContain("bad format");
    });
  });

  describe("LlmError", () => {
    it("formats ApiCallFailed", () => {
      const err = { TAG: "LlmError", _0: { TAG: "ApiCallFailed", message: "401 Unauthorized" } };
      expect(BotError.toString(err)).toContain("401 Unauthorized");
    });
  });

  describe("RiskError", () => {
    it("formats MaxDailyLossReached", () => {
      const err = { TAG: "RiskError", _0: { TAG: "MaxDailyLossReached", currentLoss: 500.0, limit: 200.0 } };
      expect(BotError.toString(err)).toContain("500");
      expect(BotError.toString(err)).toContain("200");
    });

    it("formats MaxOpenPositionsReached", () => {
      const err = { TAG: "RiskError", _0: { TAG: "MaxOpenPositionsReached", current: 5, limit: 3 } };
      expect(BotError.toString(err)).toContain("5");
      expect(BotError.toString(err)).toContain("3");
    });

    it("formats MaxPositionSizeExceeded", () => {
      const err = { TAG: "RiskError", _0: { TAG: "MaxPositionSizeExceeded", requested: 10000.0, limit: 5000.0 } };
      expect(BotError.toString(err)).toContain("10000");
      expect(BotError.toString(err)).toContain("5000");
    });
  });

  describe("EngineError", () => {
    it("formats AlreadyRunning", () => {
      const err = { TAG: "EngineError", _0: "AlreadyRunning" };
      expect(BotError.toString(err)).toBe("Engine is already running");
    });

    it("formats NotRunning", () => {
      const err = { TAG: "EngineError", _0: "NotRunning" };
      expect(BotError.toString(err)).toBe("Engine is not running");
    });

    it("formats InitializationFailed", () => {
      const err = { TAG: "EngineError", _0: { TAG: "InitializationFailed", message: "no config" } };
      expect(BotError.toString(err)).toContain("no config");
    });

    it("formats TickFailed", () => {
      const err = { TAG: "EngineError", _0: { TAG: "TickFailed", symbol: "ETHUSDT", message: "fetch error" } };
      expect(BotError.toString(err)).toContain("ETHUSDT");
    });
  });
});
