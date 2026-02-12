open Vitest

// Helper to create a candle with domain-typed fields
let candle = (openTime, open_, high, low, close, volume, closeTime): Config.candlestick => {
  openTime: Trade.Timestamp(openTime),
  open_: Trade.Price(open_),
  high: Trade.Price(high),
  low: Trade.Price(low),
  close: Trade.Price(close),
  volume: Config.Volume(volume),
  closeTime: Trade.Timestamp(closeTime),
}

describe("BaseDetector edge cases", () => {
  describe("driftPercent", () => {
    it("returns 0% when min and max are the same", () => {
      let base: BaseDetector.base = {
        priceLevel: Trade.Price(100.0),
        bounceCount: Config.BounceCount(1),
        firstSeen: Trade.Timestamp(1000.0),
        lastBounce: Trade.Timestamp(1000.0),
        minLevel: Trade.Price(100.0),
        maxLevel: Trade.Price(100.0),
      }
      let Config.DriftPercent(drift) = BaseDetector.driftPercent(base)
      expect(drift)->toBeCloseTo(0.0)
    })

    it("returns ~9.52% for min=95 max=105", () => {
      let base: BaseDetector.base = {
        priceLevel: Trade.Price(100.0),
        bounceCount: Config.BounceCount(2),
        firstSeen: Trade.Timestamp(1000.0),
        lastBounce: Trade.Timestamp(2000.0),
        minLevel: Trade.Price(95.0),
        maxLevel: Trade.Price(105.0),
      }
      // drift = (105 - 95) / 105 * 100 = 10/105*100 ~ 9.5238
      let Config.DriftPercent(drift) = BaseDetector.driftPercent(base)
      expect(drift)->toBeCloseTo(9.5238, ~digits=2)
    })

    it("returns 0% when maxLevel is zero (division guard)", () => {
      let base: BaseDetector.base = {
        priceLevel: Trade.Price(0.0),
        bounceCount: Config.BounceCount(1),
        firstSeen: Trade.Timestamp(1000.0),
        lastBounce: Trade.Timestamp(1000.0),
        minLevel: Trade.Price(0.0),
        maxLevel: Trade.Price(0.0),
      }
      let Config.DriftPercent(drift) = BaseDetector.driftPercent(base)
      expect(drift)->toBeCloseTo(0.0)
    })

    it("returns 0% when maxLevel is negative", () => {
      let base: BaseDetector.base = {
        priceLevel: Trade.Price(-5.0),
        bounceCount: Config.BounceCount(1),
        firstSeen: Trade.Timestamp(1000.0),
        lastBounce: Trade.Timestamp(1000.0),
        minLevel: Trade.Price(-10.0),
        maxLevel: Trade.Price(-5.0),
      }
      let Config.DriftPercent(drift) = BaseDetector.driftPercent(base)
      expect(drift)->toBeCloseTo(0.0)
    })
  })

  describe("clusterMinimums", () => {
    it("single minimum produces a single base with bounceCount=1", () => {
      let minimums = [(Trade.Price(100.0), Trade.Timestamp(1000.0))]
      let bases = BaseDetector.clusterMinimums(
        minimums,
        ~tolerancePercent=Config.TolerancePercent(0.5),
      )
      expect(bases->Array.length)->toBe(1)
      expect(bases[0]->Option.map(b => b.bounceCount))->toBe(Some(Config.BounceCount(1)))
      expect(bases[0]->Option.map(b => b.priceLevel))->toBe(Some(Trade.Price(100.0)))
      expect(bases[0]->Option.map(b => b.firstSeen))->toBe(Some(Trade.Timestamp(1000.0)))
      expect(bases[0]->Option.map(b => b.lastBounce))->toBe(Some(Trade.Timestamp(1000.0)))
      expect(bases[0]->Option.map(b => b.minLevel))->toBe(Some(Trade.Price(100.0)))
      expect(bases[0]->Option.map(b => b.maxLevel))->toBe(Some(Trade.Price(100.0)))
    })
  })

  describe("detectBases", () => {
    it("returns NoBases for exactly 3 candles with single minimum (below minBounces)", () => {
      // 3 candles = minimum required for a local minimum at index 1
      let candles = [
        candle(1.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 2.0),
        candle(2.0, 100.0, 105.0, 95.0, 102.0, 1000.0, 3.0), // local min at 95
        candle(3.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 4.0),
      ]
      let config: Config.baseFilterConfig = {
        minBounces: Config.BounceCount(2),
        tolerance: Config.TolerancePercent(0.5),
        maxBaseDrift: Config.DriftPercent(5.0),
      }
      let result = BaseDetector.detectBases(candles, ~config)
      expect(result)->toBe(BaseDetector.NoBases)
    })

    it("detects a base from exactly 3 candles when minBounces=1", () => {
      let candles = [
        candle(1.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 2.0),
        candle(2.0, 100.0, 105.0, 95.0, 102.0, 1000.0, 3.0), // local min at 95
        candle(3.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 4.0),
      ]
      let config: Config.baseFilterConfig = {
        minBounces: Config.BounceCount(1),
        tolerance: Config.TolerancePercent(0.5),
        maxBaseDrift: Config.DriftPercent(5.0),
      }
      switch BaseDetector.detectBases(candles, ~config) {
      | BasesFound({bases}) => {
          expect(bases->Array.length)->toBe(1)
          expect(bases[0]->Option.map(b => b.bounceCount))->toBe(Some(Config.BounceCount(1)))
        }
      | NoBases => expect(false)->toBe(true) // should not reach here
      }
    })

    it("filters out bases that exceed maxBaseDrift", () => {
      // Create two bounce points with prices far enough apart to have large drift
      // but close enough to cluster (within tolerance)
      // min=98, max=102 -> drift = (102-98)/102*100 = 3.92%
      // Set maxBaseDrift=1.0 so this base gets filtered
      let candles = [
        candle(1.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 2.0),
        candle(2.0, 100.0, 105.0, 98.0, 103.0, 1000.0, 3.0),  // min at 98
        candle(3.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 4.0),
        candle(4.0, 104.0, 108.0, 102.0, 106.0, 1000.0, 5.0),  // min at 102
        candle(5.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 6.0),
      ]
      let configStrict: Config.baseFilterConfig = {
        minBounces: Config.BounceCount(1),
        tolerance: Config.TolerancePercent(5.0), // wide tolerance so they cluster together
        maxBaseDrift: Config.DriftPercent(1.0),   // tight drift filter
      }
      let result = BaseDetector.detectBases(candles, ~config=configStrict)
      // The base has drift ~3.92% which exceeds maxBaseDrift of 1.0%
      expect(result)->toBe(BaseDetector.NoBases)
    })

    it("keeps bases within maxBaseDrift", () => {
      // min=100, max=100.1 -> drift = 0.1/100.1*100 ~ 0.10%
      let candles = [
        candle(1.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 2.0),
        candle(2.0, 105.0, 108.0, 100.0, 103.0, 1000.0, 3.0), // min at 100
        candle(3.0, 108.0, 115.0, 105.0, 112.0, 1000.0, 4.0),
        candle(4.0, 105.0, 108.0, 100.1, 103.0, 1000.0, 5.0), // min at 100.1
        candle(5.0, 108.0, 115.0, 105.0, 112.0, 1000.0, 6.0),
      ]
      let config: Config.baseFilterConfig = {
        minBounces: Config.BounceCount(2),
        tolerance: Config.TolerancePercent(0.5),
        maxBaseDrift: Config.DriftPercent(1.0),
      }
      switch BaseDetector.detectBases(candles, ~config) {
      | BasesFound({bases}) =>
        expect(bases->Array.length)->toBe(1)
      | NoBases => expect(false)->toBe(true) // should not reach here
      }
    })
  })

  describe("pricesNear edge cases", () => {
    it("returns false when both prices are zero (negative avg guard)", () => {
      expect(
        BaseDetector.pricesNear(Trade.Price(0.0), Trade.Price(0.0), ~tolerancePercent=100.0),
      )->toBe(false)
    })

    it("returns true for identical non-zero prices", () => {
      expect(
        BaseDetector.pricesNear(Trade.Price(50.0), Trade.Price(50.0), ~tolerancePercent=0.0),
      )->toBe(true)
    })

    it("returns false for zero tolerance with different prices", () => {
      expect(
        BaseDetector.pricesNear(Trade.Price(100.0), Trade.Price(100.001), ~tolerancePercent=0.0),
      )->toBe(false)
    })
  })
})
