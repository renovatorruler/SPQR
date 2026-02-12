import { describe, it, expect, beforeEach, afterEach } from "vitest";
import * as Db from "../Db.res.mjs";

let db;

beforeEach(() => {
  // In-memory SQLite — fast, isolated per test
  const result = Db.open_(":memory:");
  expect(result.TAG).toBe("Ok");
  db = result._0;
  const migrateResult = Db.migrate(db);
  expect(migrateResult.TAG).toBe("Ok");
});

afterEach(() => {
  Db.close(db);
});

describe("Db", () => {
  describe("open / migrate", () => {
    it("creates database and tables successfully", () => {
      // If we got here, beforeEach already succeeded
      expect(db).toBeDefined();
      expect(db.db).toBeDefined();
    });

    it("returns error for invalid path", () => {
      const result = Db.open_("/nonexistent/dir/test.db");
      expect(result.TAG).toBe("Error");
      expect(result._0.TAG).toBe("EngineError");
      expect(result._0._0.TAG).toBe("InitializationFailed");
    });
  });

  describe("insertTrade / trades", () => {
    it("inserts a filled buy trade", () => {
      const trade = {
        id: "trade-001",
        symbol: "BTCUSDT",
        side: "Buy",
        orderType: "Market",
        requestedQty: 0.5,
        status: { TAG: "Filled", filledPrice: 50000.0, filledAt: Date.now() },
        createdAt: Date.now(),
      };
      const result = Db.insertTrade(db, trade);
      expect(result.TAG).toBe("Ok");
    });

    it("inserts a pending trade", () => {
      const trade = {
        id: "trade-002",
        symbol: "ETHUSDT",
        side: "Sell",
        orderType: { TAG: "Limit", limitPrice: 3000.0 },
        requestedQty: 2.0,
        status: "Pending",
        createdAt: Date.now(),
      };
      const result = Db.insertTrade(db, trade);
      expect(result.TAG).toBe("Ok");
    });

    it("upserts on duplicate trade ID", () => {
      const trade = {
        id: "trade-dup",
        symbol: "BTCUSDT",
        side: "Buy",
        orderType: "Market",
        requestedQty: 1.0,
        status: { TAG: "Filled", filledPrice: 100.0, filledAt: Date.now() },
        createdAt: Date.now(),
      };
      Db.insertTrade(db, trade);
      // Insert again with same ID — should upsert
      trade.requestedQty = 2.0;
      const result = Db.insertTrade(db, trade);
      expect(result.TAG).toBe("Ok");
    });
  });

  describe("insertPosition / getOpenPositions", () => {
    it("inserts and retrieves an open position", () => {
      const pos = {
        symbol: "BTCUSDT",
        side: "Long",
        entryPrice: 50000.0,
        currentQty: 0.5,
        status: { TAG: "Open", openedAt: Date.now() },
      };
      const insertResult = Db.insertPosition(db, pos);
      expect(insertResult.TAG).toBe("Ok");

      const getResult = Db.getOpenPositions(db);
      expect(getResult.TAG).toBe("Ok");
      expect(getResult._0.length).toBe(1);
      expect(getResult._0[0].symbol).toBe("BTCUSDT");
      expect(getResult._0[0].side).toBe("Long");
      expect(getResult._0[0].entryPrice).toBe(50000.0);
      expect(getResult._0[0].currentQty).toBe(0.5);
    });

    it("does not return closed positions", () => {
      const pos = {
        symbol: "ETHUSDT",
        side: "Long",
        entryPrice: 3000.0,
        currentQty: 1.0,
        status: { TAG: "Closed", openedAt: 1000, closedAt: 2000, realizedPnl: 100.0 },
      };
      Db.insertPosition(db, pos);

      const getResult = Db.getOpenPositions(db);
      expect(getResult.TAG).toBe("Ok");
      expect(getResult._0.length).toBe(0);
    });

    it("retrieves multiple open positions", () => {
      const now = Date.now();
      Db.insertPosition(db, {
        symbol: "BTCUSDT",
        side: "Long",
        entryPrice: 50000.0,
        currentQty: 0.5,
        status: { TAG: "Open", openedAt: now },
      });
      Db.insertPosition(db, {
        symbol: "ETHUSDT",
        side: "Long",
        entryPrice: 3000.0,
        currentQty: 2.0,
        status: { TAG: "Open", openedAt: now + 1 },
      });

      const getResult = Db.getOpenPositions(db);
      expect(getResult.TAG).toBe("Ok");
      expect(getResult._0.length).toBe(2);
    });
  });

  describe("saveBases / loadBases", () => {
    it("saves and loads bases for a symbol", () => {
      const bases = [
        { priceLevel: 100.0, bounceCount: 3, firstSeen: 1000, lastBounce: 5000, minLevel: 100.0, maxLevel: 100.0 },
        { priceLevel: 95.0, bounceCount: 2, firstSeen: 2000, lastBounce: 4000, minLevel: 95.0, maxLevel: 95.0 },
      ];
      const saveResult = Db.saveBases(db, "BTCUSDT", bases);
      expect(saveResult.TAG).toBe("Ok");

      const loadResult = Db.loadBases(db, "BTCUSDT");
      expect(loadResult.TAG).toBe("Ok");
      expect(loadResult._0.length).toBe(2);
      expect(loadResult._0[0].priceLevel).toBe(100.0);
      expect(loadResult._0[0].bounceCount).toBe(3);
    });

    it("replaces bases on re-save", () => {
      Db.saveBases(db, "BTCUSDT", [
        { priceLevel: 100.0, bounceCount: 3, firstSeen: 1000, lastBounce: 5000, minLevel: 100.0, maxLevel: 100.0 },
      ]);
      Db.saveBases(db, "BTCUSDT", [
        { priceLevel: 200.0, bounceCount: 1, firstSeen: 3000, lastBounce: 6000, minLevel: 200.0, maxLevel: 200.0 },
      ]);

      const loadResult = Db.loadBases(db, "BTCUSDT");
      expect(loadResult.TAG).toBe("Ok");
      expect(loadResult._0.length).toBe(1);
      expect(loadResult._0[0].priceLevel).toBe(200.0);
    });

    it("returns empty for unknown symbol", () => {
      const loadResult = Db.loadBases(db, "UNKNOWN");
      expect(loadResult.TAG).toBe("Ok");
      expect(loadResult._0.length).toBe(0);
    });
  });

  describe("saveState / loadState", () => {
    it("saves and loads a key-value pair", () => {
      const saveResult = Db.saveState(db, "regime", "Bullish");
      expect(saveResult.TAG).toBe("Ok");

      const loadResult = Db.loadState(db, "regime");
      expect(loadResult.TAG).toBe("Ok");
      expect(loadResult._0).toBe("Bullish");
    });

    it("overwrites on re-save", () => {
      Db.saveState(db, "regime", "Bullish");
      Db.saveState(db, "regime", "Bearish");

      const loadResult = Db.loadState(db, "regime");
      expect(loadResult.TAG).toBe("Ok");
      expect(loadResult._0).toBe("Bearish");
    });

    it("returns undefined for unknown key", () => {
      const loadResult = Db.loadState(db, "nonexistent");
      expect(loadResult.TAG).toBe("Ok");
      expect(loadResult._0).toBeUndefined();
    });
  });
});
