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

describe("BaseDetector", () => {
  describe("isLocalMinimum", () => {
    it("detects a local minimum when current low is below neighbors", () => {
      let candles = [
        candle(1.0, 105.0, 110.0, 100.0, 108.0, 1000.0, 2.0),
        candle(2.0, 95.0, 100.0, 90.0, 98.0, 1000.0, 3.0), // local min at 90
        candle(3.0, 105.0, 110.0, 100.0, 108.0, 1000.0, 4.0),
      ]
      expect(BaseDetector.isLocalMinimum(candles, 1))->toBe(true)
    })

    it("rejects when current is not the lowest", () => {
      let candles = [
        candle(1.0, 95.0, 100.0, 85.0, 98.0, 1000.0, 2.0),
        candle(2.0, 95.0, 100.0, 90.0, 98.0, 1000.0, 3.0), // 90 > 85, not a min
        candle(3.0, 105.0, 110.0, 100.0, 108.0, 1000.0, 4.0),
      ]
      expect(BaseDetector.isLocalMinimum(candles, 1))->toBe(false)
    })

    it("returns false for first index (no prev neighbor)", () => {
      let candles = [
        candle(1.0, 95.0, 100.0, 80.0, 98.0, 1000.0, 2.0),
        candle(2.0, 95.0, 100.0, 90.0, 98.0, 1000.0, 3.0),
      ]
      expect(BaseDetector.isLocalMinimum(candles, 0))->toBe(false)
    })

    it("returns false for last index (no next neighbor)", () => {
      let candles = [
        candle(1.0, 95.0, 100.0, 90.0, 98.0, 1000.0, 2.0),
        candle(2.0, 95.0, 100.0, 80.0, 98.0, 1000.0, 3.0),
      ]
      expect(BaseDetector.isLocalMinimum(candles, 1))->toBe(false)
    })
  })

  describe("pricesNear", () => {
    it("returns true for prices within tolerance", () => {
      // 100 and 100.4 -> diff = 0.4, avg = 100.2, pct = 0.4/100.2*100 ~ 0.399 < 0.5
      expect(
        BaseDetector.pricesNear(Trade.Price(100.0), Trade.Price(100.4), ~tolerancePercent=0.5),
      )->toBe(true)
    })

    it("returns false for prices outside tolerance", () => {
      // 100 and 102 -> diff = 2, avg = 101, pct = 2/101*100 ~ 1.98 > 0.5
      expect(
        BaseDetector.pricesNear(Trade.Price(100.0), Trade.Price(102.0), ~tolerancePercent=0.5),
      )->toBe(false)
    })

    it("returns false when avg is zero", () => {
      expect(
        BaseDetector.pricesNear(Trade.Price(0.0), Trade.Price(0.0), ~tolerancePercent=0.5),
      )->toBe(false)
    })

    it("is symmetric", () => {
      expect(
        BaseDetector.pricesNear(Trade.Price(100.0), Trade.Price(100.3), ~tolerancePercent=0.5),
      )->toBe(
        BaseDetector.pricesNear(Trade.Price(100.3), Trade.Price(100.0), ~tolerancePercent=0.5),
      )
    })
  })

  describe("clusterMinimums", () => {
    it("clusters nearby prices into a single base", () => {
      let minimums = [
        (Trade.Price(100.0), Trade.Timestamp(1000.0)),
        (Trade.Price(100.2), Trade.Timestamp(2000.0)),
        (Trade.Price(100.1), Trade.Timestamp(3000.0)),
      ]
      let bases = BaseDetector.clusterMinimums(
        minimums,
        ~tolerancePercent=Config.TolerancePercent(0.5),
      )
      expect(bases->Array.length)->toBe(1)
      expect(bases[0]->Option.map(b => b.bounceCount))->toBe(Some(Config.BounceCount(3)))
    })

    it("separates distant prices into different bases", () => {
      let minimums = [
        (Trade.Price(100.0), Trade.Timestamp(1000.0)),
        (Trade.Price(200.0), Trade.Timestamp(2000.0)),
      ]
      let bases = BaseDetector.clusterMinimums(
        minimums,
        ~tolerancePercent=Config.TolerancePercent(0.5),
      )
      expect(bases->Array.length)->toBe(2)
    })

    it("returns empty for empty input", () => {
      let bases = BaseDetector.clusterMinimums(
        [],
        ~tolerancePercent=Config.TolerancePercent(0.5),
      )
      expect(bases->Array.length)->toBe(0)
    })
  })

  describe("detectBases", () => {
    let baseFilter: Config.baseFilterConfig = {
      minBounces: Config.BounceCount(2),
      tolerance: Config.TolerancePercent(0.5),
      maxBaseDrift: Config.DriftPercent(1.0),
    }

    it("returns NoBases for fewer than 3 candles", () => {
      let result = BaseDetector.detectBases(
        [candle(1.0, 100.0, 110.0, 90.0, 105.0, 1000.0, 2.0)],
        ~config=baseFilter,
      )
      expect(result)->toBe(BaseDetector.NoBases)
    })

    it("returns NoBases when no local minimums exist", () => {
      // Ascending sequence -- no local min
      let candles = [
        candle(1.0, 100.0, 110.0, 95.0, 105.0, 1000.0, 2.0),
        candle(2.0, 105.0, 115.0, 100.0, 110.0, 1000.0, 3.0),
        candle(3.0, 110.0, 120.0, 105.0, 115.0, 1000.0, 4.0),
        candle(4.0, 115.0, 125.0, 110.0, 120.0, 1000.0, 5.0),
      ]
      let result = BaseDetector.detectBases(candles, ~config=baseFilter)
      expect(result)->toBe(BaseDetector.NoBases)
    })

    it("detects bases with enough bounces", () => {
      // Create a W pattern: two bounces at ~100
      let candles = [
        candle(1.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 2.0),
        candle(2.0, 105.0, 108.0, 100.0, 103.0, 1000.0, 3.0), // min at 100
        candle(3.0, 108.0, 115.0, 105.0, 112.0, 1000.0, 4.0),
        candle(4.0, 105.0, 108.0, 100.1, 103.0, 1000.0, 5.0), // min at 100.1
        candle(5.0, 108.0, 115.0, 105.0, 112.0, 1000.0, 6.0),
      ]
      switch BaseDetector.detectBases(candles, ~config=baseFilter) {
      | BasesFound({bases}) => {
          expect(bases->Array.length)->toBe(1)
          expect(bases[0]->Option.map(b => b.bounceCount))->toBe(Some(Config.BounceCount(2)))
        }
      | NoBases => expect(false)->toBe(true) // should not reach here
      }
    })

    it("filters bases below minBounces", () => {
      // Single bounce -- won't pass minBounces=2
      let candles = [
        candle(1.0, 110.0, 115.0, 105.0, 112.0, 1000.0, 2.0),
        candle(2.0, 105.0, 108.0, 100.0, 103.0, 1000.0, 3.0), // single min
        candle(3.0, 108.0, 115.0, 105.0, 112.0, 1000.0, 4.0),
      ]
      let result = BaseDetector.detectBases(candles, ~config=baseFilter)
      expect(result)->toBe(BaseDetector.NoBases)
    })

    it("sorts bases by bounce count descending", () => {
      // Two base zones, one with more bounces
      let candles = [
        candle(1.0, 210.0, 215.0, 205.0, 212.0, 1000.0, 2.0),
        candle(2.0, 205.0, 208.0, 200.0, 203.0, 1000.0, 3.0), // min at 200
        candle(3.0, 210.0, 215.0, 205.0, 212.0, 1000.0, 4.0),
        candle(4.0, 205.0, 208.0, 200.1, 203.0, 1000.0, 5.0), // min at 200.1
        candle(5.0, 210.0, 215.0, 205.0, 212.0, 1000.0, 6.0),
        candle(6.0, 110.0, 115.0, 105.0, 108.0, 1000.0, 7.0),
        candle(7.0, 105.0, 108.0, 100.0, 103.0, 1000.0, 8.0), // min at 100
        candle(8.0, 110.0, 115.0, 105.0, 108.0, 1000.0, 9.0),
        candle(9.0, 105.0, 108.0, 100.1, 103.0, 1000.0, 10.0), // min at 100.1
        candle(10.0, 110.0, 115.0, 105.0, 108.0, 1000.0, 11.0),
        candle(11.0, 105.0, 108.0, 100.2, 103.0, 1000.0, 12.0), // min at 100.2
        candle(12.0, 110.0, 115.0, 105.0, 108.0, 1000.0, 13.0),
      ]
      switch BaseDetector.detectBases(candles, ~config=baseFilter) {
      | BasesFound({bases}) => {
          expect(bases->Array.length)->toBe(2)
          // Base at ~100 has 3 bounces, base at ~200 has 2
          let first = bases[0]->Option.map(b => b.bounceCount)
          let second = bases[1]->Option.map(b => b.bounceCount)
          switch (first, second) {
          | (Some(Config.BounceCount(a)), Some(Config.BounceCount(b))) =>
            expect(a)->toBeGreaterThanOrEqual(b)
          | _ => expect(false)->toBe(true) // should not reach here
          }
        }
      | NoBases => expect(false)->toBe(true) // should not reach here
      }
    })
  })
})
