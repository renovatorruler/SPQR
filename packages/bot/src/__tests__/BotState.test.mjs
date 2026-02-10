import { describe, it, expect, beforeEach, afterEach } from "vitest";
import * as Db from "../Db.res.mjs";
import * as BotState from "../BotState.res.mjs";
import * as RiskManager from "../RiskManager.res.mjs";

const riskLimits = {
  maxPositionSize: 10000.0,
  maxOpenPositions: 3,
  maxDailyLoss: 500.0,
};

let db;

beforeEach(() => {
  const result = Db.open_(":memory:");
  expect(result.TAG).toBe("Ok");
  db = result._0;
  Db.migrate(db);
});

afterEach(() => {
  Db.close(db);
});

describe("BotState", () => {
  describe("make", () => {
    it("creates state with empty symbol states", () => {
      const state = BotState.make(db, riskLimits);
      expect(state.regime).toBe("Unknown");
      expect(state.lastRegimeCheck).toBeUndefined();
      expect(Object.keys(state.symbolStates).length).toBe(0);
    });

    it("initializes risk manager", () => {
      const state = BotState.make(db, riskLimits);
      expect(RiskManager.isHalted(state.riskManager)).toBe(false);
    });
  });

  describe("getSymbolState", () => {
    it("creates default state for new symbol", () => {
      const state = BotState.make(db, riskLimits);
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.bases.length).toBe(0);
      expect(ss.openPosition).toBeUndefined();
    });

    it("returns same state on subsequent calls", () => {
      const state = BotState.make(db, riskLimits);
      const ss1 = BotState.getSymbolState(state, "BTCUSDT");
      const ss2 = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss1).toBe(ss2); // same reference
    });

    it("isolates state per symbol", () => {
      const state = BotState.make(db, riskLimits);
      const btc = BotState.getSymbolState(state, "BTCUSDT");
      const eth = BotState.getSymbolState(state, "ETHUSDT");
      expect(btc).not.toBe(eth);
    });
  });

  describe("updateBases", () => {
    it("updates bases for a symbol", () => {
      const state = BotState.make(db, riskLimits);
      const bases = [
        { priceLevel: 100.0, bounceCount: 3, firstSeen: 1000, lastBounce: 5000 },
      ];
      BotState.updateBases(state, "BTCUSDT", bases);
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.bases.length).toBe(1);
      expect(ss.bases[0].priceLevel).toBe(100.0);
    });

    it("persists bases to database", () => {
      const state = BotState.make(db, riskLimits);
      BotState.updateBases(state, "BTCUSDT", [
        { priceLevel: 100.0, bounceCount: 3, firstSeen: 1000, lastBounce: 5000 },
      ]);
      const loaded = Db.loadBases(db, "BTCUSDT");
      expect(loaded.TAG).toBe("Ok");
      expect(loaded._0.length).toBe(1);
    });
  });

  describe("setOpenPosition", () => {
    it("sets position info for a symbol", () => {
      const state = BotState.make(db, riskLimits);
      const posInfo = {
        entryPrice: 50000.0,
        base: { priceLevel: 48000.0, bounceCount: 3, firstSeen: 1000, lastBounce: 5000 },
      };
      BotState.setOpenPosition(state, "BTCUSDT", posInfo);
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.openPosition).toBeDefined();
      expect(ss.openPosition.entryPrice).toBe(50000.0);
    });

    it("clears position when set to undefined", () => {
      const state = BotState.make(db, riskLimits);
      BotState.setOpenPosition(state, "BTCUSDT", {
        entryPrice: 50000.0,
        base: { priceLevel: 48000.0, bounceCount: 3, firstSeen: 1000, lastBounce: 5000 },
      });
      BotState.setOpenPosition(state, "BTCUSDT", undefined);
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.openPosition).toBeUndefined();
    });
  });

  describe("updateRegime", () => {
    it("updates regime and timestamp", () => {
      const state = BotState.make(db, riskLimits);
      const before = Date.now();
      BotState.updateRegime(state, { TAG: "TrendingUp", confidence: 0.8 });
      expect(state.regime.TAG).toBe("TrendingUp");
      expect(state.lastRegimeCheck).toBeGreaterThanOrEqual(before);
    });

    it("persists regime to database", () => {
      const state = BotState.make(db, riskLimits);
      // Regime is a variant: { TAG: "TrendingDown", confidence: 0.7 }
      BotState.updateRegime(state, { TAG: "TrendingDown", confidence: 0.7 });
      const loaded = Db.loadState(db, "regime");
      expect(loaded.TAG).toBe("Ok");
      expect(loaded._0).toBe("Trending Down (0.7)");
    });
  });

  describe("isRegimeStale", () => {
    it("returns true when never checked", () => {
      const state = BotState.make(db, riskLimits);
      expect(BotState.isRegimeStale(state, 60000)).toBe(true);
    });

    it("returns false immediately after update", () => {
      const state = BotState.make(db, riskLimits);
      BotState.updateRegime(state, "Bullish");
      expect(BotState.isRegimeStale(state, 60000)).toBe(false);
    });
  });

  describe("restore", () => {
    it("restores state from database with open positions", () => {
      // Seed a position in the DB
      Db.insertPosition(db, {
        symbol: "BTCUSDT",
        side: "Long",
        entryPrice: 50000.0,
        currentQty: 0.5,
        status: { TAG: "Open", openedAt: Date.now() },
      });

      const result = BotState.restore(db, riskLimits);
      expect(result.TAG).toBe("Ok");
      const state = result._0;
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.openPosition).toBeDefined();
      expect(ss.openPosition.entryPrice).toBe(50000.0);
    });

    it("restores empty state when no positions", () => {
      const result = BotState.restore(db, riskLimits);
      expect(result.TAG).toBe("Ok");
      expect(Object.keys(result._0.symbolStates).length).toBe(0);
    });
  });

  describe("persist", () => {
    it("saves current regime to database", () => {
      const state = BotState.make(db, riskLimits);
      // Set regime to a valid variant (HighVolatility with confidence)
      state.regime = { TAG: "HighVolatility", confidence: 0.9 };
      BotState.persist(state);
      const loaded = Db.loadState(db, "regime");
      expect(loaded.TAG).toBe("Ok");
      expect(loaded._0).toBe("High Volatility (0.9)");
    });
  });
});
