import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import * as Db from "../Db.res.mjs";
import * as BotState from "../BotState.res.mjs";
import * as BotLoop from "../BotLoop.res.mjs";
import * as PaperExchange from "../PaperExchange.res.mjs";
import * as RiskManager from "../RiskManager.res.mjs";

// Mock CcxtMarketData to avoid real network calls
vi.mock("../CcxtMarketData.res.mjs", () => {
  // W-pattern candles that create a base at ~100
  const defaultCandles = [
    { openTime: 1, open_: 110, high: 115, low: 105, close: 112, volume: 1000, closeTime: 2 },
    { openTime: 2, open_: 105, high: 108, low: 100, close: 103, volume: 1000, closeTime: 3 },
    { openTime: 3, open_: 108, high: 115, low: 105, close: 112, volume: 1000, closeTime: 4 },
    { openTime: 4, open_: 105, high: 108, low: 100.1, close: 103, volume: 1000, closeTime: 5 },
    { openTime: 5, open_: 108, high: 115, low: 105, close: 112, volume: 1000, closeTime: 6 },
  ];

  let mockPrice = 112.0;
  let mockCandles = defaultCandles;

  return {
    make: (config) => ({ TAG: "Ok", _0: { config } }),
    getCandles: async () => ({ TAG: "Ok", _0: mockCandles }),
    getCurrentPrice: async () => ({ TAG: "Ok", _0: mockPrice }),
    // Test helpers (not part of real module)
    __setMockPrice: (p) => { mockPrice = p; },
    __setMockCandles: (c) => { mockCandles = c; },
    __resetMocks: () => {
      mockPrice = 112.0;
      mockCandles = defaultCandles;
    },
  };
});

// We need to dynamically import after mocking
const CcxtMarketDataMock = await import("../CcxtMarketData.res.mjs");

function makeConfig(overrides = {}) {
  return {
    tradingMode: "Paper",
    exchange: { exchangeId: "PaperExchange" },
    symbols: ["BTCUSDT"],
    riskLimits: {
      maxPositionSize: 10000.0,
      maxOpenPositions: 3,
      maxDailyLoss: 500.0,
    },
    qfl: {
      crackThreshold: 3.0,
      baseFilter: {
        minBounces: 2,
        tolerance: 0.5,
        maxBaseDrift: 1.0,
      },
      exitPolicy: {
        stopLoss: 5.0,
        takeProfit: 2.0,
        maxHold: 16,
      },
      reentry: "NoReentry",
      regimeGate: {
        emaFast: 50,
        emaSlow: 200,
        emaSlopeLookback: 20,
      },
      setupEvaluation: "Disabled",
      lookbackCandles: 50,
    },
    llm: undefined,
    marketData: {
      source: { TAG: "Ccxt", _0: { exchangeId: "kraken" } },
      defaultInterval: "1h",
    },
    engine: {
      pollIntervalMs: 100, // Fast for tests
      closeOnShutdown: false,
    },
    ...overrides,
  };
}

let db;
let exchange;
let marketData;

beforeEach(() => {
  CcxtMarketDataMock.__resetMocks();

  const dbResult = Db.open_(":memory:");
  expect(dbResult.TAG).toBe("Ok");
  db = dbResult._0;
  Db.migrate(db);

  const exResult = PaperExchange.make({ exchangeId: "PaperExchange" });
  exchange = exResult._0;

  const mdResult = CcxtMarketDataMock.make({
    source: { exchangeId: "kraken" },
    defaultInterval: "1h",
  });
  marketData = mdResult._0;
});

afterEach(() => {
  Db.close(db);
});

describe("BotLoop E2E", () => {
  describe("make", () => {
    it("creates engine in Initializing state", () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      expect(engine.engineState).toBe("Initializing");
      expect(engine.tickCount).toBe(0);
    });
  });

  describe("tick", () => {
    it("increments tick count", async () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      await BotLoop.tick(engine);
      expect(engine.tickCount).toBe(1);

      await BotLoop.tick(engine);
      expect(engine.tickCount).toBe(2);
    });

    it("detects bases from candle data", async () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      await BotLoop.tick(engine);

      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.bases.length).toBeGreaterThan(0);
    });

    it("persists state after tick", async () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      await BotLoop.tick(engine);

      // State should be persisted (regime saved to DB)
      const loaded = Db.loadState(db, "regime");
      expect(loaded.TAG).toBe("Ok");
    });
  });

  describe("processSymbol — crack detection and buy", () => {
    it("places buy order when crack detected", async () => {
      // Set price 5% below the base (~100) → should trigger crack
      CcxtMarketDataMock.__setMockPrice(95.0);

      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      // Set price in paper exchange so the order can fill
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 95.0);

      const result = await BotLoop.processSymbol(engine, "BTCUSDT");
      expect(result.TAG).toBe("Ok");

      // Should have opened a position
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.openPosition).toBeDefined();
      expect(ss.openPosition.entryPrice).toBe(95.0);
    });

    it("respects risk limits on buy", async () => {
      CcxtMarketDataMock.__setMockPrice(95.0);

      const config = makeConfig({
        riskLimits: {
          maxPositionSize: 1.0, // Very small — qty will be tiny but value = 1.0
          maxOpenPositions: 3,
          maxDailyLoss: 500.0,
        },
      });
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 95.0);

      const result = await BotLoop.processSymbol(engine, "BTCUSDT");
      expect(result.TAG).toBe("Ok");

      // With maxPositionSize=1.0, qty = 1.0/95.0 ≈ 0.0105, posValue ≈ 1.0
      // This is within the 1.0 limit, so it should succeed
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.openPosition).toBeDefined();
    });
  });

  describe("processSymbol — no signal when price above bases", () => {
    it("does nothing when price is above all bases", async () => {
      // Price at 112 (above base at ~100) — no crack
      CcxtMarketDataMock.__setMockPrice(112.0);

      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      const result = await BotLoop.processSymbol(engine, "BTCUSDT");
      expect(result.TAG).toBe("Ok");

      // No position should be opened
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.openPosition).toBeUndefined();
    });
  });

  describe("processSymbol — stop loss", () => {
    it("triggers stop loss when loss exceeds threshold", async () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      // Simulate an open position at entry 97 (cracked below base at 100)
      BotState.setOpenPosition(state, "BTCUSDT", {
        entryPrice: 97.0,
        base: {
          priceLevel: 100.0,
          bounceCount: 3,
          firstSeen: 1000,
          lastBounce: 5000,
          minLevel: 100.0,
          maxLevel: 100.0,
        },
      });
      RiskManager.recordOpen(state.riskManager);

      // Also record position in DB so sell has qty
      Db.insertPosition(db, {
        symbol: "BTCUSDT",
        side: "Long",
        entryPrice: 97.0,
        currentQty: 100.0,
        status: { TAG: "Open", openedAt: Date.now() },
      });

      // Price drops to 90 → 7.2% loss > 5% threshold
      CcxtMarketDataMock.__setMockPrice(90.0);
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 90.0);

      const result = await BotLoop.processSymbol(engine, "BTCUSDT");
      expect(result.TAG).toBe("Ok");

      // Position should be closed
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.openPosition).toBeUndefined();
    });
  });

  describe("processSymbol — bounce back", () => {
    it("takes profit on bounce back to base level", async () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      // Open position at 95 (cracked below base at 100)
      BotState.setOpenPosition(state, "BTCUSDT", {
        entryPrice: 95.0,
        base: {
          priceLevel: 100.0,
          bounceCount: 3,
          firstSeen: 1000,
          lastBounce: 5000,
          minLevel: 100.0,
          maxLevel: 100.0,
        },
      });
      RiskManager.recordOpen(state.riskManager);

      Db.insertPosition(db, {
        symbol: "BTCUSDT",
        side: "Long",
        entryPrice: 95.0,
        currentQty: 50.0,
        status: { TAG: "Open", openedAt: Date.now() },
      });

      // Price bounces back to 102 → above base at 100
      CcxtMarketDataMock.__setMockPrice(102.0);
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 102.0);

      const result = await BotLoop.processSymbol(engine, "BTCUSDT");
      expect(result.TAG).toBe("Ok");

      // Position should be closed (took profit)
      const ss = BotState.getSymbolState(state, "BTCUSDT");
      expect(ss.openPosition).toBeUndefined();
    });
  });

  describe("stop / lifecycle", () => {
    it("stop sets engine to ShuttingDown", () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);
      engine.engineState = "Running";

      BotLoop.stop(engine);
      expect(engine.engineState).toBe("ShuttingDown");
    });

    it("runLoop exits immediately when not Running", async () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);
      // engineState is "Initializing", not "Running"

      await BotLoop.runLoop(engine);
      expect(engine.tickCount).toBe(0);
    });

    it("start runs ticks then stops", async () => {
      const config = makeConfig();
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      // Start and immediately stop after first tick
      const startPromise = BotLoop.start(engine);

      // Give it a moment to enter the loop, then stop
      await new Promise(resolve => setTimeout(resolve, 50));
      BotLoop.stop(engine);

      await startPromise;
      expect(engine.engineState).toBe("Stopped");
      expect(engine.tickCount).toBeGreaterThanOrEqual(1);
    });

    it("halts on risk limit breach", async () => {
      const config = makeConfig({
        riskLimits: {
          maxPositionSize: 10000.0,
          maxOpenPositions: 0, // No positions allowed
          maxDailyLoss: 500.0,
        },
      });
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      // Set up crack detection scenario
      CcxtMarketDataMock.__setMockPrice(95.0);
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 95.0);

      // Manually trigger a risk halt by exceeding position count
      RiskManager.recordOpen(state.riskManager);
      // checkEntry will set halted=true
      RiskManager.checkEntry(state.riskManager, 100.0, 200.0);

      const startPromise = BotLoop.start(engine);
      await startPromise;

      // Engine should have stopped due to risk halt
      expect(engine.engineState).toBe("Stopped");
    });
  });

  describe("multi-symbol", () => {
    it("processes multiple symbols in a single tick", async () => {
      const config = makeConfig({ symbols: ["BTCUSDT", "ETHUSDT"] });
      const state = BotState.make(db, config.riskLimits);
      const engine = BotLoop.make(exchange, marketData, state, config);

      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 112.0);
      PaperExchange.setCurrentPrice(exchange, "ETHUSDT", 112.0);

      await BotLoop.tick(engine);

      // Both symbols should have state entries
      const btcState = BotState.getSymbolState(state, "BTCUSDT");
      const ethState = BotState.getSymbolState(state, "ETHUSDT");
      expect(btcState.bases).toBeDefined();
      expect(ethState.bases).toBeDefined();
    });
  });
});
