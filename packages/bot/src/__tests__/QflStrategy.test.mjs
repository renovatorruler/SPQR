import { describe, it, expect } from "vitest";
import * as QflStrategy from "../QflStrategy.res.mjs";

function makeBase(priceLevel, bounceCount = 3) {
  return {
    priceLevel,
    bounceCount,
    firstSeen: 1000,
    lastBounce: 5000,
    minLevel: priceLevel,
    maxLevel: priceLevel,
  };
}

describe("QflStrategy", () => {
  describe("checkForCrack", () => {
    it("detects a crack when price is below base by threshold", () => {
      const bases = [makeBase(100.0)];
      // Price 95.0 → 5% below base of 100
      const result = QflStrategy.checkForCrack(bases, 95.0, 3.0, "BTCUSDT");
      expect(result.TAG).toBe("CrackDetected");
      expect(result.crackPercent).toBeCloseTo(5.0, 1);
      expect(result.symbol).toBe("BTCUSDT");
    });

    it("returns NoSignal when price is above base", () => {
      const bases = [makeBase(100.0)];
      const result = QflStrategy.checkForCrack(bases, 105.0, 3.0, "BTCUSDT");
      expect(result).toBe("NoSignal");
    });

    it("returns NoSignal when crack is below threshold", () => {
      const bases = [makeBase(100.0)];
      // Price 99.0 → 1% below, threshold is 3%
      const result = QflStrategy.checkForCrack(bases, 99.0, 3.0, "BTCUSDT");
      expect(result).toBe("NoSignal");
    });

    it("returns NoSignal for empty bases", () => {
      const result = QflStrategy.checkForCrack([], 95.0, 3.0, "BTCUSDT");
      expect(result).toBe("NoSignal");
    });

    it("picks the first cracked base", () => {
      const bases = [makeBase(100.0), makeBase(90.0)];
      // Price 96.0 → 4% below 100, 6.67% below — but only first that cracks above threshold
      const result = QflStrategy.checkForCrack(bases, 96.0, 3.0, "BTCUSDT");
      expect(result.TAG).toBe("CrackDetected");
      expect(result.base.priceLevel).toBe(100.0);
    });
  });

  describe("checkForBounce", () => {
    it("detects bounce when price returns to base level", () => {
      const base = makeBase(100.0);
      const result = QflStrategy.checkForBounce(95.0, 100.0, base, "BTCUSDT");
      expect(result.TAG).toBe("BounceBack");
      expect(result.entryPrice).toBe(95.0);
    });

    it("detects bounce when price exceeds base level", () => {
      const base = makeBase(100.0);
      const result = QflStrategy.checkForBounce(95.0, 105.0, base, "BTCUSDT");
      expect(result.TAG).toBe("BounceBack");
    });

    it("returns NoSignal when price still below base", () => {
      const base = makeBase(100.0);
      const result = QflStrategy.checkForBounce(95.0, 98.0, base, "BTCUSDT");
      expect(result).toBe("NoSignal");
    });
  });

  describe("checkStopLoss", () => {
    it("triggers stop loss when loss exceeds threshold", () => {
      // Entry 100, current 90 → 10% loss, threshold 5%
      const result = QflStrategy.checkStopLoss(100.0, 90.0, 5.0, "BTCUSDT");
      expect(result.TAG).toBe("StopLossTriggered");
      expect(result.lossPercent).toBeCloseTo(10.0, 1);
    });

    it("returns NoSignal when loss is below threshold", () => {
      // Entry 100, current 98 → 2% loss, threshold 5%
      const result = QflStrategy.checkStopLoss(100.0, 98.0, 5.0, "BTCUSDT");
      expect(result).toBe("NoSignal");
    });

    it("returns NoSignal when price is above entry (profit)", () => {
      const result = QflStrategy.checkStopLoss(100.0, 105.0, 5.0, "BTCUSDT");
      expect(result).toBe("NoSignal");
    });
  });

  describe("analyze", () => {
    function candle(openTime, open_, high, low, close, volume, closeTime) {
      return { openTime, open_, high, low, close, volume, closeTime };
    }

    const qflConfig = {
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
    };

    it("returns error for insufficient candles", () => {
      const result = QflStrategy.analyze(
        [candle(1, 100, 110, 90, 105, 1000, 2)],
        95.0, "BTCUSDT", qflConfig, undefined
      );
      expect(result.TAG).toBe("Error");
      expect(result._0.TAG).toBe("StrategyError");
    });

    it("returns NoSignal when no bases detected and no position", () => {
      // Ascending candles → no bases
      const candles = [
        candle(1, 100, 110, 95, 105, 1000, 2),
        candle(2, 105, 115, 100, 110, 1000, 3),
        candle(3, 110, 120, 105, 115, 1000, 4),
      ];
      const result = QflStrategy.analyze(candles, 115.0, "BTCUSDT", qflConfig, undefined);
      expect(result.TAG).toBe("Ok");
      expect(result._0).toBe("NoSignal");
    });

    it("prioritizes stop loss over bounce for open position", () => {
      // W pattern candles to establish a base at ~100
      const candles = [
        candle(1, 110, 115, 105, 112, 1000, 2),
        candle(2, 105, 108, 100, 103, 1000, 3),
        candle(3, 108, 115, 105, 112, 1000, 4),
        candle(4, 105, 108, 100, 103, 1000, 5),
        candle(5, 108, 115, 105, 112, 1000, 6),
      ];

      const openPosition = {
        entryPrice: 97.0,
        base: makeBase(100.0),
      };

      // Current price 90 → loss = 7.2% > 5% threshold → stop loss
      const result = QflStrategy.analyze(candles, 90.0, "BTCUSDT", qflConfig, openPosition);
      expect(result.TAG).toBe("Ok");
      expect(result._0.TAG).toBe("StopLossTriggered");
    });
  });
});
