import { describe, it, expect } from "vitest";
import * as BaseDetector from "../BaseDetector.res.mjs";

// Helper to create a candle (fields match compiled candlestick shape — @unboxed means raw values)
function candle(openTime, open_, high, low, close, volume, closeTime) {
  return { openTime, open_, high, low, close, volume, closeTime };
}

describe("BaseDetector", () => {
  describe("isLocalMinimum", () => {
    it("detects a local minimum when current low is below neighbors", () => {
      const candles = [
        candle(1, 105, 110, 100, 108, 1000, 2),
        candle(2, 95, 100, 90, 98, 1000, 3),   // local min at 90
        candle(3, 105, 110, 100, 108, 1000, 4),
      ];
      expect(BaseDetector.isLocalMinimum(candles, 1)).toBe(true);
    });

    it("rejects when current is not the lowest", () => {
      const candles = [
        candle(1, 95, 100, 85, 98, 1000, 2),
        candle(2, 95, 100, 90, 98, 1000, 3),   // 90 > 85, not a min
        candle(3, 105, 110, 100, 108, 1000, 4),
      ];
      expect(BaseDetector.isLocalMinimum(candles, 1)).toBe(false);
    });

    it("returns false for first index (no prev neighbor)", () => {
      const candles = [
        candle(1, 95, 100, 80, 98, 1000, 2),
        candle(2, 95, 100, 90, 98, 1000, 3),
      ];
      expect(BaseDetector.isLocalMinimum(candles, 0)).toBe(false);
    });

    it("returns false for last index (no next neighbor)", () => {
      const candles = [
        candle(1, 95, 100, 90, 98, 1000, 2),
        candle(2, 95, 100, 80, 98, 1000, 3),
      ];
      expect(BaseDetector.isLocalMinimum(candles, 1)).toBe(false);
    });
  });

  describe("pricesNear", () => {
    it("returns true for prices within tolerance", () => {
      // 100 and 100.4 → diff = 0.4, avg = 100.2, pct = 0.4/100.2*100 ≈ 0.399 < 0.5
      expect(BaseDetector.pricesNear(100.0, 100.4, 0.5)).toBe(true);
    });

    it("returns false for prices outside tolerance", () => {
      // 100 and 102 → diff = 2, avg = 101, pct = 2/101*100 ≈ 1.98 > 0.5
      expect(BaseDetector.pricesNear(100.0, 102.0, 0.5)).toBe(false);
    });

    it("returns false when avg is zero", () => {
      expect(BaseDetector.pricesNear(0.0, 0.0, 0.5)).toBe(false);
    });

    it("is symmetric", () => {
      expect(BaseDetector.pricesNear(100.0, 100.3, 0.5))
        .toBe(BaseDetector.pricesNear(100.3, 100.0, 0.5));
    });
  });

  describe("clusterMinimums", () => {
    it("clusters nearby prices into a single base", () => {
      const minimums = [
        [100.0, 1000],
        [100.2, 2000],
        [100.1, 3000],
      ];
      const bases = BaseDetector.clusterMinimums(minimums, 0.5);
      expect(bases.length).toBe(1);
      expect(bases[0].bounceCount).toBe(3);
    });

    it("separates distant prices into different bases", () => {
      const minimums = [
        [100.0, 1000],
        [200.0, 2000],
      ];
      const bases = BaseDetector.clusterMinimums(minimums, 0.5);
      expect(bases.length).toBe(2);
    });

    it("returns empty for empty input", () => {
      const bases = BaseDetector.clusterMinimums([], 0.5);
      expect(bases.length).toBe(0);
    });
  });

  describe("detectBases", () => {
    it("returns NoBases for fewer than 3 candles", () => {
      const baseFilter = { minBounces: 2, tolerance: 0.5, maxBaseDrift: 1.0 };
      const result = BaseDetector.detectBases([candle(1, 100, 110, 90, 105, 1000, 2)], baseFilter);
      expect(result).toBe("NoBases");
    });

    it("returns NoBases when no local minimums exist", () => {
      const baseFilter = { minBounces: 2, tolerance: 0.5, maxBaseDrift: 1.0 };
      // Ascending sequence — no local min
      const candles = [
        candle(1, 100, 110, 95, 105, 1000, 2),
        candle(2, 105, 115, 100, 110, 1000, 3),
        candle(3, 110, 120, 105, 115, 1000, 4),
        candle(4, 115, 125, 110, 120, 1000, 5),
      ];
      const result = BaseDetector.detectBases(candles, baseFilter);
      expect(result).toBe("NoBases");
    });

    it("detects bases with enough bounces", () => {
      const baseFilter = { minBounces: 2, tolerance: 0.5, maxBaseDrift: 1.0 };
      // Create a W pattern: two bounces at ~100
      const candles = [
        candle(1, 110, 115, 105, 112, 1000, 2),
        candle(2, 105, 108, 100, 103, 1000, 3),  // min at 100
        candle(3, 108, 115, 105, 112, 1000, 4),
        candle(4, 105, 108, 100.1, 103, 1000, 5), // min at 100.1
        candle(5, 108, 115, 105, 112, 1000, 6),
      ];
      const result = BaseDetector.detectBases(candles, baseFilter);
      expect(result).not.toBe("NoBases");
      expect(result.TAG).toBe("BasesFound");
      expect(result.bases.length).toBe(1);
      expect(result.bases[0].bounceCount).toBe(2);
    });

    it("filters bases below minBounces", () => {
      const baseFilter = { minBounces: 2, tolerance: 0.5, maxBaseDrift: 1.0 };
      // Single bounce — won't pass minBounces=2
      const candles = [
        candle(1, 110, 115, 105, 112, 1000, 2),
        candle(2, 105, 108, 100, 103, 1000, 3),  // single min
        candle(3, 108, 115, 105, 112, 1000, 4),
      ];
      const result = BaseDetector.detectBases(candles, baseFilter);
      expect(result).toBe("NoBases");
    });

    it("sorts bases by bounce count descending", () => {
      const baseFilter = { minBounces: 2, tolerance: 0.5, maxBaseDrift: 1.0 };
      // Two base zones, one with more bounces
      const candles = [
        candle(1, 210, 215, 205, 212, 1000, 2),
        candle(2, 205, 208, 200, 203, 1000, 3),  // min at 200
        candle(3, 210, 215, 205, 212, 1000, 4),
        candle(4, 205, 208, 200.1, 203, 1000, 5), // min at 200.1
        candle(5, 210, 215, 205, 212, 1000, 6),
        candle(6, 110, 115, 105, 108, 1000, 7),
        candle(7, 105, 108, 100, 103, 1000, 8),   // min at 100
        candle(8, 110, 115, 105, 108, 1000, 9),
        candle(9, 105, 108, 100.1, 103, 1000, 10), // min at 100.1
        candle(10, 110, 115, 105, 108, 1000, 11),
        candle(11, 105, 108, 100.2, 103, 1000, 12), // min at 100.2
        candle(12, 110, 115, 105, 108, 1000, 13),
      ];
      const result = BaseDetector.detectBases(candles, baseFilter);
      expect(result.TAG).toBe("BasesFound");
      expect(result.bases.length).toBe(2);
      // Base at ~100 has 3 bounces, base at ~200 has 2
      expect(result.bases[0].bounceCount).toBeGreaterThanOrEqual(result.bases[1].bounceCount);
    });
  });
});
