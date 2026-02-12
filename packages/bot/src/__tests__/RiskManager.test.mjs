import { describe, it, expect } from "vitest";
import * as RiskManager from "../RiskManager.res.mjs";

// @unboxed types compile to raw values
function makeConfig() {
  return {
    maxPositionSize: 10000.0,   // Trade.Quantity(10000.0) → 10000.0
    maxOpenPositions: 3,
    maxDailyLoss: 500.0,        // Position.Pnl(500.0) → 500.0
  };
}

describe("RiskManager", () => {
  describe("make", () => {
    it("creates a fresh risk manager", () => {
      const rm = RiskManager.make(makeConfig());
      expect(rm.halted).toBe(false);
      expect(rm.openPositionCount).toBe(0);
      expect(rm.dailyPnl).toBe(0.0);
    });
  });

  describe("isHalted", () => {
    it("returns false for fresh manager", () => {
      const rm = RiskManager.make(makeConfig());
      expect(RiskManager.isHalted(rm)).toBe(false);
    });
  });

  describe("checkEntry", () => {
    it("allows entry under all limits", () => {
      const rm = RiskManager.make(makeConfig());
      const result = RiskManager.checkEntry(rm, 1.0, 100.0);
      expect(result).toBe("Allowed");
    });

    it("blocks when position size exceeds limit", () => {
      const rm = RiskManager.make(makeConfig());
      // qty=100, price=200 → position value 20000 > maxPositionSize 10000
      const result = RiskManager.checkEntry(rm, 100.0, 200.0);
      expect(result.TAG).toBe("Blocked");
      expect(result._0._0.TAG).toBe("MaxPositionSizeExceeded");
    });

    it("blocks when max open positions reached", () => {
      const rm = RiskManager.make(makeConfig());
      RiskManager.recordOpen(rm);
      RiskManager.recordOpen(rm);
      RiskManager.recordOpen(rm);
      // Now at 3 open positions, max is 3
      const result = RiskManager.checkEntry(rm, 1.0, 100.0);
      expect(result.TAG).toBe("Blocked");
      expect(result._0._0.TAG).toBe("MaxOpenPositionsReached");
    });

    it("blocks when daily loss limit reached", () => {
      const rm = RiskManager.make(makeConfig());
      // Record a big loss
      RiskManager.recordClose(rm, -600.0);
      const result = RiskManager.checkEntry(rm, 1.0, 100.0);
      expect(result.TAG).toBe("Blocked");
      expect(result._0._0.TAG).toBe("MaxDailyLossReached");
    });

    it("blocks all entries once halted", () => {
      const rm = RiskManager.make(makeConfig());
      // Trigger halt via position size
      RiskManager.checkEntry(rm, 100.0, 200.0);
      expect(RiskManager.isHalted(rm)).toBe(true);
      // Any subsequent entry is blocked too
      const result = RiskManager.checkEntry(rm, 0.01, 1.0);
      expect(result.TAG).toBe("Blocked");
    });
  });

  describe("recordOpen / recordClose", () => {
    it("increments open position count", () => {
      const rm = RiskManager.make(makeConfig());
      RiskManager.recordOpen(rm);
      expect(rm.openPositionCount).toBe(1);
      RiskManager.recordOpen(rm);
      expect(rm.openPositionCount).toBe(2);
    });

    it("decrements open position count on close", () => {
      const rm = RiskManager.make(makeConfig());
      RiskManager.recordOpen(rm);
      RiskManager.recordOpen(rm);
      RiskManager.recordClose(rm, 50.0);
      expect(rm.openPositionCount).toBe(1);
    });

    it("does not go below zero", () => {
      const rm = RiskManager.make(makeConfig());
      RiskManager.recordClose(rm, 0.0);
      expect(rm.openPositionCount).toBe(0);
    });

    it("accumulates daily PnL", () => {
      const rm = RiskManager.make(makeConfig());
      RiskManager.recordClose(rm, 100.0);
      RiskManager.recordClose(rm, -50.0);
      expect(rm.dailyPnl).toBeCloseTo(50.0);
    });
  });

  describe("resetDaily", () => {
    it("resets PnL and halted state", () => {
      const rm = RiskManager.make(makeConfig());
      RiskManager.recordClose(rm, -600.0);
      RiskManager.checkEntry(rm, 1.0, 100.0); // triggers halt
      expect(RiskManager.isHalted(rm)).toBe(true);

      RiskManager.resetDaily(rm);
      expect(rm.dailyPnl).toBe(0.0);
      expect(RiskManager.isHalted(rm)).toBe(false);
    });
  });
});
