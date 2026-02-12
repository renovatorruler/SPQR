open Vitest

let makeConfig = () => {
  Config.maxPositionSize: Trade.Quantity(10000.0),
  maxOpenPositions: Config.MaxOpenPositions(3),
  maxDailyLoss: Position.Pnl(500.0),
}

describe("RiskManager", () => {
  describe("make", () => {
    it("creates a fresh risk manager", () => {
      let rm = RiskManager.make(makeConfig())
      expect(rm.halted)->toBe(false)
      let Config.OpenPositionsCount(count) = rm.openPositionCount
      expect(count)->toBe(0)
      let Position.Pnl(pnl) = rm.dailyPnl
      expect(pnl)->toBe(0.0)
    })
  })

  describe("isHalted", () => {
    it("returns false for fresh manager", () => {
      let rm = RiskManager.make(makeConfig())
      expect(RiskManager.isHalted(rm))->toBe(false)
    })
  })

  describe("checkEntry", () => {
    it("allows entry under all limits", () => {
      let rm = RiskManager.make(makeConfig())
      let result = RiskManager.checkEntry(rm, ~qty=Trade.Quantity(1.0), ~price=Trade.Price(100.0))
      switch result {
      | Allowed => expect(true)->toBe(true)
      | Blocked(_) => expect(true)->toBe(false)
      }
    })

    it("blocks when position size exceeds limit", () => {
      let rm = RiskManager.make(makeConfig())
      // qty=100, price=200 -> position value 20000 > maxPositionSize 10000
      let result = RiskManager.checkEntry(
        rm,
        ~qty=Trade.Quantity(100.0),
        ~price=Trade.Price(200.0),
      )
      switch result {
      | Blocked(RiskError(MaxPositionSizeExceeded(_))) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("blocks when max open positions reached", () => {
      let rm = RiskManager.make(makeConfig())
      RiskManager.recordOpen(rm)
      RiskManager.recordOpen(rm)
      RiskManager.recordOpen(rm)
      // Now at 3 open positions, max is 3
      let result = RiskManager.checkEntry(rm, ~qty=Trade.Quantity(1.0), ~price=Trade.Price(100.0))
      switch result {
      | Blocked(RiskError(MaxOpenPositionsReached(_))) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("blocks when daily loss limit reached", () => {
      let rm = RiskManager.make(makeConfig())
      // Record a big loss
      RiskManager.recordClose(rm, Position.Pnl(-600.0))
      let result = RiskManager.checkEntry(rm, ~qty=Trade.Quantity(1.0), ~price=Trade.Price(100.0))
      switch result {
      | Blocked(RiskError(MaxDailyLossReached(_))) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("blocks all entries once halted", () => {
      let rm = RiskManager.make(makeConfig())
      // Trigger halt via position size
      let _ = RiskManager.checkEntry(rm, ~qty=Trade.Quantity(100.0), ~price=Trade.Price(200.0))
      expect(RiskManager.isHalted(rm))->toBe(true)
      // Any subsequent entry is blocked too
      let result = RiskManager.checkEntry(
        rm,
        ~qty=Trade.Quantity(0.01),
        ~price=Trade.Price(1.0),
      )
      switch result {
      | Blocked(_) => expect(true)->toBe(true)
      | Allowed => expect(true)->toBe(false)
      }
    })
  })

  describe("recordOpen / recordClose", () => {
    it("increments open position count", () => {
      let rm = RiskManager.make(makeConfig())
      RiskManager.recordOpen(rm)
      let Config.OpenPositionsCount(count1) = rm.openPositionCount
      expect(count1)->toBe(1)
      RiskManager.recordOpen(rm)
      let Config.OpenPositionsCount(count2) = rm.openPositionCount
      expect(count2)->toBe(2)
    })

    it("decrements open position count on close", () => {
      let rm = RiskManager.make(makeConfig())
      RiskManager.recordOpen(rm)
      RiskManager.recordOpen(rm)
      RiskManager.recordClose(rm, Position.Pnl(50.0))
      let Config.OpenPositionsCount(count) = rm.openPositionCount
      expect(count)->toBe(1)
    })

    it("does not go below zero", () => {
      let rm = RiskManager.make(makeConfig())
      RiskManager.recordClose(rm, Position.Pnl(0.0))
      let Config.OpenPositionsCount(count) = rm.openPositionCount
      expect(count)->toBe(0)
    })

    it("accumulates daily PnL", () => {
      let rm = RiskManager.make(makeConfig())
      RiskManager.recordClose(rm, Position.Pnl(100.0))
      RiskManager.recordClose(rm, Position.Pnl(-50.0))
      let Position.Pnl(pnl) = rm.dailyPnl
      expect(pnl)->toBeCloseTo(50.0)
    })
  })

  describe("resetDaily", () => {
    it("resets PnL and halted state", () => {
      let rm = RiskManager.make(makeConfig())
      RiskManager.recordClose(rm, Position.Pnl(-600.0))
      let _ = RiskManager.checkEntry(rm, ~qty=Trade.Quantity(1.0), ~price=Trade.Price(100.0)) // triggers halt
      expect(RiskManager.isHalted(rm))->toBe(true)

      RiskManager.resetDaily(rm)
      let Position.Pnl(pnl) = rm.dailyPnl
      expect(pnl)->toBe(0.0)
      expect(RiskManager.isHalted(rm))->toBe(false)
    })
  })
})
