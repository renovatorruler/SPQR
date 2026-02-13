open Vitest

describe("Position", () => {
  describe("make", () => {
    it("creates an Open position with correct fields", () => {
      let pos = Position.make(
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Position.Long,
        ~entryPrice=Trade.Price(100.0),
        ~qty=Trade.Quantity(10.0),
        ~openedAt=Trade.Timestamp(1000.0),
      )
      expect(pos.symbol)->toBe(Trade.Symbol("BTCUSDT"))
      expect(pos.side)->toBe(Position.Long)
      expect(pos.entryPrice)->toBe(Trade.Price(100.0))
      expect(pos.currentQty)->toBe(Trade.Quantity(10.0))
      expect(pos.status)->toEqual(Position.Open({openedAt: Trade.Timestamp(1000.0)}))
    })
  })

  describe("unrealizedPnl", () => {
    it("is positive when Long and price goes up", () => {
      let pos = Position.make(
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Position.Long,
        ~entryPrice=Trade.Price(100.0),
        ~qty=Trade.Quantity(10.0),
        ~openedAt=Trade.Timestamp(1000.0),
      )
      let Position.Pnl(pnl) = Position.unrealizedPnl(pos, Trade.Price(110.0))
      // (110 - 100) * 10 = 100
      expect(pnl)->toBeCloseTo(100.0)
    })

    it("is negative when Long and price goes down", () => {
      let pos = Position.make(
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Position.Long,
        ~entryPrice=Trade.Price(100.0),
        ~qty=Trade.Quantity(10.0),
        ~openedAt=Trade.Timestamp(1000.0),
      )
      let Position.Pnl(pnl) = Position.unrealizedPnl(pos, Trade.Price(90.0))
      // (90 - 100) * 10 = -100
      expect(pnl)->toBeCloseTo(-100.0)
    })

    it("is positive when Short and price goes down", () => {
      let pos = Position.make(
        ~symbol=Trade.Symbol("ETHUSDT"),
        ~side=Position.Short,
        ~entryPrice=Trade.Price(200.0),
        ~qty=Trade.Quantity(5.0),
        ~openedAt=Trade.Timestamp(2000.0),
      )
      let Position.Pnl(pnl) = Position.unrealizedPnl(pos, Trade.Price(180.0))
      // (200 - 180) * 5 = 100
      expect(pnl)->toBeCloseTo(100.0)
    })

    it("is negative when Short and price goes up", () => {
      let pos = Position.make(
        ~symbol=Trade.Symbol("ETHUSDT"),
        ~side=Position.Short,
        ~entryPrice=Trade.Price(200.0),
        ~qty=Trade.Quantity(5.0),
        ~openedAt=Trade.Timestamp(2000.0),
      )
      let Position.Pnl(pnl) = Position.unrealizedPnl(pos, Trade.Price(220.0))
      // (200 - 220) * 5 = -100
      expect(pnl)->toBeCloseTo(-100.0)
    })

    it("handles zero quantity", () => {
      let pos = Position.make(
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Position.Long,
        ~entryPrice=Trade.Price(100.0),
        ~qty=Trade.Quantity(0.0),
        ~openedAt=Trade.Timestamp(1000.0),
      )
      let Position.Pnl(pnl) = Position.unrealizedPnl(pos, Trade.Price(150.0))
      // (150 - 100) * 0 = 0
      expect(pnl)->toBeCloseTo(0.0)
    })
  })

  describe("computePnl", () => {
    it("matches unrealizedPnl for Long with price up", () => {
      let Position.Pnl(pnl) = Position.computePnl(
        ~side=Position.Long,
        ~entryPrice=Trade.Price(100.0),
        ~currentPrice=Trade.Price(110.0),
        ~qty=Trade.Quantity(10.0),
      )
      // (110 - 100) * 10 = 100
      expect(pnl)->toBeCloseTo(100.0)
    })

    it("matches unrealizedPnl for Short with price down", () => {
      let Position.Pnl(pnl) = Position.computePnl(
        ~side=Position.Short,
        ~entryPrice=Trade.Price(200.0),
        ~currentPrice=Trade.Price(180.0),
        ~qty=Trade.Quantity(5.0),
      )
      // (200 - 180) * 5 = 100
      expect(pnl)->toBeCloseTo(100.0)
    })

    it("returns negative PnL for Long with price down", () => {
      let Position.Pnl(pnl) = Position.computePnl(
        ~side=Position.Long,
        ~entryPrice=Trade.Price(100.0),
        ~currentPrice=Trade.Price(80.0),
        ~qty=Trade.Quantity(3.0),
      )
      // (80 - 100) * 3 = -60
      expect(pnl)->toBeCloseTo(-60.0)
    })

    it("returns negative PnL for Short with price up", () => {
      let Position.Pnl(pnl) = Position.computePnl(
        ~side=Position.Short,
        ~entryPrice=Trade.Price(200.0),
        ~currentPrice=Trade.Price(250.0),
        ~qty=Trade.Quantity(2.0),
      )
      // (200 - 250) * 2 = -100
      expect(pnl)->toBeCloseTo(-100.0)
    })

    it("returns zero PnL for zero quantity", () => {
      let Position.Pnl(pnl) = Position.computePnl(
        ~side=Position.Long,
        ~entryPrice=Trade.Price(100.0),
        ~currentPrice=Trade.Price(200.0),
        ~qty=Trade.Quantity(0.0),
      )
      expect(pnl)->toBeCloseTo(0.0)
    })
  })

  describe("Closed status", () => {
    it("carries realizedPnl and timestamps", () => {
      let closedStatus: Position.positionStatus = Closed({
        openedAt: Trade.Timestamp(1000.0),
        closedAt: Trade.Timestamp(5000.0),
        realizedPnl: Position.Pnl(250.0),
      })
      switch closedStatus {
      | Closed({openedAt, closedAt, realizedPnl}) => {
          expect(openedAt)->toBe(Trade.Timestamp(1000.0))
          expect(closedAt)->toBe(Trade.Timestamp(5000.0))
          expect(realizedPnl)->toBe(Position.Pnl(250.0))
        }
      | Open(_) => expect(false)->toBe(true) // should not reach here
      }
    })

    it("distinguishes Open from Closed via pattern match", () => {
      let pos = Position.make(
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Position.Long,
        ~entryPrice=Trade.Price(100.0),
        ~qty=Trade.Quantity(1.0),
        ~openedAt=Trade.Timestamp(1000.0),
      )
      let isOpen = switch pos.status {
      | Open(_) => true
      | Closed(_) => false
      }
      expect(isOpen)->toBe(true)
    })
  })
})
