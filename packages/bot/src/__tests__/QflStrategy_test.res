open Vitest

let makeBase = (~priceLevel, ~bounceCount=Config.BounceCount(3), ()): BaseDetector.base => {
  priceLevel: Trade.Price(priceLevel),
  bounceCount,
  firstSeen: Trade.Timestamp(1000.0),
  lastBounce: Trade.Timestamp(5000.0),
  minLevel: Trade.Price(priceLevel),
  maxLevel: Trade.Price(priceLevel),
}

let makeCandle = (
  ~openTime,
  ~open_,
  ~high,
  ~low,
  ~close,
  ~volume,
  ~closeTime,
): Config.candlestick => {
  openTime: Trade.Timestamp(openTime),
  open_: Trade.Price(open_),
  high: Trade.Price(high),
  low: Trade.Price(low),
  close: Trade.Price(close),
  volume: Config.Volume(volume),
  closeTime: Trade.Timestamp(closeTime),
}

let qflConfig: Config.qflConfig = {
  crackThreshold: Config.CrackPercent(3.0),
  baseFilter: {
    minBounces: Config.BounceCount(2),
    tolerance: Config.TolerancePercent(0.5),
    maxBaseDrift: Config.DriftPercent(1.0),
  },
  exitPolicy: {
    stopLoss: Config.StopLossPercent(5.0),
    takeProfit: Config.TakeProfitPercent(2.0),
    maxHold: Config.HoldCandles(16),
  },
  reentry: Config.NoReentry,
  regimeGate: {
    emaFast: Config.EmaPeriod(50),
    emaSlow: Config.EmaPeriod(200),
    emaSlopeLookback: Config.EmaSlopeLookback(20),
  },
  setupEvaluation: Config.Disabled,
  lookbackCandles: Config.CandleCount(50),
}

describe("QflStrategy", () => {
  describe("checkForCrack", () => {
    it("detects a crack when price is below base by threshold", () => {
      let bases = [makeBase(~priceLevel=100.0, ())]
      // Price 95.0 -> 5% below base of 100
      switch QflStrategy.checkForCrack(
        ~bases,
        ~currentPrice=Trade.Price(95.0),
        ~crackThreshold=Config.CrackPercent(3.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
      ) {
      | CrackDetected({crackPercent: Config.CrackPercent(pct), symbol: Trade.Symbol(sym)}) =>
        expect(pct)->toBeCloseTo(5.0, ~digits=1)
        expect(sym)->toBe("BTCUSDT")
      | _ => expect(true)->toBe(false)
      }
    })

    it("returns NoSignal when price is above base", () => {
      let bases = [makeBase(~priceLevel=100.0, ())]
      let result = QflStrategy.checkForCrack(
        ~bases,
        ~currentPrice=Trade.Price(105.0),
        ~crackThreshold=Config.CrackPercent(3.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
      )
      expect(result)->toBe(QflStrategy.NoSignal)
    })

    it("returns NoSignal when crack is below threshold", () => {
      let bases = [makeBase(~priceLevel=100.0, ())]
      // Price 99.0 -> 1% below, threshold is 3%
      let result = QflStrategy.checkForCrack(
        ~bases,
        ~currentPrice=Trade.Price(99.0),
        ~crackThreshold=Config.CrackPercent(3.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
      )
      expect(result)->toBe(QflStrategy.NoSignal)
    })

    it("returns NoSignal for empty bases", () => {
      let result = QflStrategy.checkForCrack(
        ~bases=[],
        ~currentPrice=Trade.Price(95.0),
        ~crackThreshold=Config.CrackPercent(3.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
      )
      expect(result)->toBe(QflStrategy.NoSignal)
    })

    it("picks the first cracked base", () => {
      let bases = [makeBase(~priceLevel=100.0, ()), makeBase(~priceLevel=90.0, ())]
      // Price 96.0 -> 4% below 100, but only first that cracks above threshold
      switch QflStrategy.checkForCrack(
        ~bases,
        ~currentPrice=Trade.Price(96.0),
        ~crackThreshold=Config.CrackPercent(3.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
      ) {
      | CrackDetected({base}) =>
        expect(base.priceLevel)->toBe(Trade.Price(100.0))
      | _ => expect(true)->toBe(false)
      }
    })
  })

  describe("checkForBounce", () => {
    it("detects bounce when price returns to base level", () => {
      let base = makeBase(~priceLevel=100.0, ())
      switch QflStrategy.checkForBounce(
        ~entryPrice=Trade.Price(95.0),
        ~currentPrice=Trade.Price(100.0),
        ~base,
        ~symbol=Trade.Symbol("BTCUSDT"),
      ) {
      | BounceBack({entryPrice}) =>
        expect(entryPrice)->toBe(Trade.Price(95.0))
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects bounce when price exceeds base level", () => {
      let base = makeBase(~priceLevel=100.0, ())
      switch QflStrategy.checkForBounce(
        ~entryPrice=Trade.Price(95.0),
        ~currentPrice=Trade.Price(105.0),
        ~base,
        ~symbol=Trade.Symbol("BTCUSDT"),
      ) {
      | BounceBack(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("returns NoSignal when price still below base", () => {
      let base = makeBase(~priceLevel=100.0, ())
      let result = QflStrategy.checkForBounce(
        ~entryPrice=Trade.Price(95.0),
        ~currentPrice=Trade.Price(98.0),
        ~base,
        ~symbol=Trade.Symbol("BTCUSDT"),
      )
      expect(result)->toBe(QflStrategy.NoSignal)
    })
  })

  describe("checkStopLoss", () => {
    it("triggers stop loss when loss exceeds threshold", () => {
      // Entry 100, current 90 -> 10% loss, threshold 5%
      switch QflStrategy.checkStopLoss(
        ~entryPrice=Trade.Price(100.0),
        ~currentPrice=Trade.Price(90.0),
        ~stopLossThreshold=Config.StopLossPercent(5.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
      ) {
      | StopLossTriggered({lossPercent: Config.StopLossPercent(pct)}) =>
        expect(pct)->toBeCloseTo(10.0, ~digits=1)
      | _ => expect(true)->toBe(false)
      }
    })

    it("returns NoSignal when loss is below threshold", () => {
      // Entry 100, current 98 -> 2% loss, threshold 5%
      let result = QflStrategy.checkStopLoss(
        ~entryPrice=Trade.Price(100.0),
        ~currentPrice=Trade.Price(98.0),
        ~stopLossThreshold=Config.StopLossPercent(5.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
      )
      expect(result)->toBe(QflStrategy.NoSignal)
    })

    it("returns NoSignal when price is above entry (profit)", () => {
      let result = QflStrategy.checkStopLoss(
        ~entryPrice=Trade.Price(100.0),
        ~currentPrice=Trade.Price(105.0),
        ~stopLossThreshold=Config.StopLossPercent(5.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
      )
      expect(result)->toBe(QflStrategy.NoSignal)
    })
  })

  describe("analyze", () => {
    it("returns error for insufficient candles", () => {
      let candles = [makeCandle(~openTime=1.0, ~open_=100.0, ~high=110.0, ~low=90.0, ~close=105.0, ~volume=1000.0, ~closeTime=2.0)]
      let result = QflStrategy.analyze(
        ~candles,
        ~currentPrice=Trade.Price(95.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~config=qflConfig,
        ~openPosition=None,
      )
      switch result {
      | Error(StrategyError(_)) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("returns NoSignal when no bases detected and no position", () => {
      // Ascending candles -> no bases
      let candles = [
        makeCandle(~openTime=1.0, ~open_=100.0, ~high=110.0, ~low=95.0, ~close=105.0, ~volume=1000.0, ~closeTime=2.0),
        makeCandle(~openTime=2.0, ~open_=105.0, ~high=115.0, ~low=100.0, ~close=110.0, ~volume=1000.0, ~closeTime=3.0),
        makeCandle(~openTime=3.0, ~open_=110.0, ~high=120.0, ~low=105.0, ~close=115.0, ~volume=1000.0, ~closeTime=4.0),
      ]
      let result = QflStrategy.analyze(
        ~candles,
        ~currentPrice=Trade.Price(115.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~config=qflConfig,
        ~openPosition=None,
      )
      switch result {
      | Ok(NoSignal) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("prioritizes stop loss over bounce for open position", () => {
      // W pattern candles to establish a base at ~100
      let candles = [
        makeCandle(~openTime=1.0, ~open_=110.0, ~high=115.0, ~low=105.0, ~close=112.0, ~volume=1000.0, ~closeTime=2.0),
        makeCandle(~openTime=2.0, ~open_=105.0, ~high=108.0, ~low=100.0, ~close=103.0, ~volume=1000.0, ~closeTime=3.0),
        makeCandle(~openTime=3.0, ~open_=108.0, ~high=115.0, ~low=105.0, ~close=112.0, ~volume=1000.0, ~closeTime=4.0),
        makeCandle(~openTime=4.0, ~open_=105.0, ~high=108.0, ~low=100.0, ~close=103.0, ~volume=1000.0, ~closeTime=5.0),
        makeCandle(~openTime=5.0, ~open_=108.0, ~high=115.0, ~low=105.0, ~close=112.0, ~volume=1000.0, ~closeTime=6.0),
      ]

      let openPosition: QflStrategy.openPositionInfo = {
        entryPrice: Trade.Price(97.0),
        qty: Trade.Quantity(100.0),
        base: makeBase(~priceLevel=100.0, ()),
      }

      // Current price 90 -> loss = 7.2% > 5% threshold -> stop loss
      let result = QflStrategy.analyze(
        ~candles,
        ~currentPrice=Trade.Price(90.0),
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~config=qflConfig,
        ~openPosition=Some(openPosition),
      )
      switch result {
      | Ok(StopLossTriggered(_)) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })
  })
})
