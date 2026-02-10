import { describe, it, expect } from "vitest";
import * as BotConfig from "../BotConfig.res.mjs";

function validConfig() {
  return {
    tradingMode: "paper",
    exchange: { exchangeId: "paper" },
    symbols: ["BTCUSDT", "ETHUSDT"],
    riskLimits: {
      maxPositionSize: 10000.0,
      maxOpenPositions: 3,
      maxDailyLoss: 500.0,
    },
    qfl: {
      crackThreshold: 3.0,
      stopLossThreshold: 5.0,
      takeProfitTarget: 2.0,
      minBouncesForBase: 2,
      lookbackCandles: 50,
    },
    marketData: {
      source: "binance",
      defaultInterval: "1h",
    },
  };
}

describe("BotConfig", () => {
  describe("decode", () => {
    it("decodes a valid minimal config", () => {
      const result = BotConfig.decode(validConfig());
      expect(result.TAG).toBe("Ok");
      expect(result._0.tradingMode).toBe("Paper");
      expect(result._0.exchange.exchangeId).toBe("PaperExchange");
      expect(result._0.symbols).toEqual(["BTCUSDT", "ETHUSDT"]);
      expect(result._0.qfl.crackThreshold).toBe(3.0);
      expect(result._0.llm).toBeUndefined();
    });

    it("decodes config with LLM section", () => {
      const cfg = validConfig();
      cfg.llm = {
        apiKey: "sk-test-123",
        model: "claude-sonnet-4-5-20250929",
        regimeCheckIntervalMs: 60000,
        evaluateSetups: true,
      };
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Ok");
      expect(result._0.llm).toBeDefined();
      expect(result._0.llm.apiKey).toBe("sk-test-123");
      expect(result._0.llm.evaluateSetups).toBe(true);
    });

    it("decodes engine config with defaults", () => {
      const result = BotConfig.decode(validConfig());
      expect(result.TAG).toBe("Ok");
      expect(result._0.engine.pollIntervalMs).toBe(30000);
      expect(result._0.engine.closeOnShutdown).toBe(false);
    });

    it("decodes custom engine config", () => {
      const cfg = validConfig();
      cfg.engine = { pollIntervalMs: 5000, closeOnShutdown: true };
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Ok");
      expect(result._0.engine.pollIntervalMs).toBe(5000);
      expect(result._0.engine.closeOnShutdown).toBe(true);
    });

    it("rejects non-object JSON", () => {
      const result = BotConfig.decode("not an object");
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("ParseFailed");
    });

    it("rejects missing tradingMode", () => {
      const cfg = validConfig();
      delete cfg.tradingMode;
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("MissingField");
      expect(result._0._0.fieldName).toBe("tradingMode");
    });

    it("rejects invalid tradingMode", () => {
      const cfg = validConfig();
      cfg.tradingMode = "yolo";
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("InvalidValue");
      expect(result._0._0.fieldName).toBe("tradingMode");
    });

    it("rejects missing exchange", () => {
      const cfg = validConfig();
      delete cfg.exchange;
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.fieldName).toBe("exchange");
    });

    it("rejects invalid exchangeId", () => {
      const cfg = validConfig();
      cfg.exchange = { exchangeId: "kraken" };
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("InvalidValue");
    });

    it("rejects missing symbols", () => {
      const cfg = validConfig();
      delete cfg.symbols;
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.fieldName).toBe("symbols");
    });

    it("rejects non-string values in symbols array", () => {
      const cfg = validConfig();
      cfg.symbols = ["BTCUSDT", 123];
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("InvalidValue");
      expect(result._0._0.fieldName).toBe("symbols");
    });

    it("rejects missing riskLimits", () => {
      const cfg = validConfig();
      delete cfg.riskLimits;
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.fieldName).toBe("riskLimits");
    });

    it("rejects missing riskLimits fields", () => {
      const cfg = validConfig();
      cfg.riskLimits = { maxPositionSize: 10000.0 };
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("MissingField");
    });

    it("rejects missing qfl section", () => {
      const cfg = validConfig();
      delete cfg.qfl;
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.fieldName).toBe("qfl");
    });

    it("rejects missing qfl fields", () => {
      const cfg = validConfig();
      cfg.qfl = { crackThreshold: 3.0 };
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("MissingField");
    });

    it("rejects missing marketData", () => {
      const cfg = validConfig();
      delete cfg.marketData;
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.fieldName).toBe("marketData");
    });

    it("rejects invalid marketData source", () => {
      const cfg = validConfig();
      cfg.marketData = { source: "coinbase", defaultInterval: "1h" };
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("InvalidValue");
    });

    it("rejects invalid LLM config (missing fields)", () => {
      const cfg = validConfig();
      cfg.llm = { apiKey: "sk-test" };
      const result = BotConfig.decode(cfg);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("MissingField");
    });
  });

  describe("decodeExchangeId", () => {
    it("decodes all valid exchange IDs", () => {
      expect(BotConfig.decodeExchangeId("paper")).toBe("PaperExchange");
      expect(BotConfig.decodeExchangeId("binance")).toBe("Binance");
      expect(BotConfig.decodeExchangeId("uniswap")).toBe("Uniswap");
      expect(BotConfig.decodeExchangeId("jupiter")).toBe("Jupiter");
    });

    it("returns undefined for unknown exchange", () => {
      expect(BotConfig.decodeExchangeId("kraken")).toBeUndefined();
    });
  });

  describe("decodeTradingMode", () => {
    it("decodes valid modes", () => {
      expect(BotConfig.decodeTradingMode("paper")).toBe("Paper");
      expect(BotConfig.decodeTradingMode("live")).toBe("Live");
    });

    it("returns undefined for unknown mode", () => {
      expect(BotConfig.decodeTradingMode("demo")).toBeUndefined();
    });
  });

  describe("loadFromFile", () => {
    it("returns FileNotFound for non-existent file", () => {
      const result = BotConfig.loadFromFile("/tmp/nonexistent_spqr_config.json");
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("FileNotFound");
    });
  });
});
