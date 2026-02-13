open Vitest

let dbRef: ref<option<Db.t>> = ref(None)
let getDb = () => dbRef.contents->Option.getOrThrow

beforeEach(() => {
  switch Db.open_(":memory:") {
  | Ok(db) =>
    dbRef := Some(db)
    switch Db.migrate(db) {
    | Ok() => ()
    | Error(_) => expect(true)->toBe(false)
    }
  | Error(_) => expect(true)->toBe(false)
  }
})

afterEach(() => {
  Db.close(getDb())
  dbRef := None
})

describe("Db", () => {
  describe("open / migrate", () => {
    it("creates database and tables successfully", () => {
      let db = getDb()
      expect(db)->toBeDefined
    })

    it("returns error for invalid path", () => {
      let result = Db.open_("/nonexistent/dir/test.db")
      switch result {
      | Error(BotError.EngineError(InitializationFailed(_))) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })
  })

  describe("insertTrade / trades", () => {
    it("inserts a filled buy trade", () => {
      let trade = {
        ...Trade.make(
          ~id=Trade.TradeId("trade-001"),
          ~symbol=Trade.Symbol("BTCUSDT"),
          ~side=Trade.Buy,
          ~orderType=Trade.Market,
          ~requestedQty=Trade.Quantity(0.5),
          ~createdAt=Trade.Timestamp(Date.now()),
        ),
        status: Trade.Filled({
          filledPrice: Trade.Price(50000.0),
          filledAt: Trade.Timestamp(Date.now()),
        }),
      }
      switch Db.insertTrade(getDb(), trade) {
      | Ok() => expect(true)->toBe(true)
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("inserts a pending trade", () => {
      let trade = Trade.make(
        ~id=Trade.TradeId("trade-002"),
        ~symbol=Trade.Symbol("ETHUSDT"),
        ~side=Trade.Sell,
        ~orderType=Trade.Limit({limitPrice: Trade.Price(3000.0)}),
        ~requestedQty=Trade.Quantity(2.0),
        ~createdAt=Trade.Timestamp(Date.now()),
      )
      switch Db.insertTrade(getDb(), trade) {
      | Ok() => expect(true)->toBe(true)
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("upserts on duplicate trade ID", () => {
      let trade = {
        ...Trade.make(
          ~id=Trade.TradeId("trade-dup"),
          ~symbol=Trade.Symbol("BTCUSDT"),
          ~side=Trade.Buy,
          ~orderType=Trade.Market,
          ~requestedQty=Trade.Quantity(1.0),
          ~createdAt=Trade.Timestamp(Date.now()),
        ),
        status: Trade.Filled({
          filledPrice: Trade.Price(100.0),
          filledAt: Trade.Timestamp(Date.now()),
        }),
      }
      let _ = Db.insertTrade(getDb(), trade)
      // Insert again with same ID but different qty — should upsert
      let trade2 = {...trade, requestedQty: Trade.Quantity(2.0)}
      switch Db.insertTrade(getDb(), trade2) {
      | Ok() => expect(true)->toBe(true)
      | Error(_) => expect(true)->toBe(false)
      }
    })
  })

  describe("insertPosition / getOpenPositions", () => {
    it("inserts and retrieves an open position", () => {
      let pos: Position.position = {
        symbol: Trade.Symbol("BTCUSDT"),
        side: Position.Long,
        entryPrice: Trade.Price(50000.0),
        currentQty: Trade.Quantity(0.5),
        status: Position.Open({openedAt: Trade.Timestamp(Date.now())}),
      }
      switch Db.insertPosition(getDb(), pos) {
      | Ok() =>
        switch Db.getOpenPositions(getDb()) {
        | Ok(positions) =>
          expect(positions)->toHaveLength(1)
          switch positions[0] {
          | Some(p) =>
            expect(p.symbol)->toBe(Trade.Symbol("BTCUSDT"))
            expect(p.side)->toBe(Position.Long)
            expect(p.entryPrice)->toBe(Trade.Price(50000.0))
            expect(p.currentQty)->toBe(Trade.Quantity(0.5))
          | None => expect(true)->toBe(false)
          }
        | Error(_) => expect(true)->toBe(false)
        }
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("does not return closed positions", () => {
      let pos: Position.position = {
        symbol: Trade.Symbol("ETHUSDT"),
        side: Position.Long,
        entryPrice: Trade.Price(3000.0),
        currentQty: Trade.Quantity(1.0),
        status: Position.Closed({
          openedAt: Trade.Timestamp(1000.0),
          closedAt: Trade.Timestamp(2000.0),
          realizedPnl: Position.Pnl(100.0),
        }),
      }
      let _ = Db.insertPosition(getDb(), pos)
      switch Db.getOpenPositions(getDb()) {
      | Ok(positions) => expect(positions)->toHaveLength(0)
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("retrieves multiple open positions", () => {
      let now = Date.now()
      let _ = Db.insertPosition(
        getDb(),
        {
          symbol: Trade.Symbol("BTCUSDT"),
          side: Position.Long,
          entryPrice: Trade.Price(50000.0),
          currentQty: Trade.Quantity(0.5),
          status: Position.Open({openedAt: Trade.Timestamp(now)}),
        },
      )
      let _ = Db.insertPosition(
        getDb(),
        {
          symbol: Trade.Symbol("ETHUSDT"),
          side: Position.Long,
          entryPrice: Trade.Price(3000.0),
          currentQty: Trade.Quantity(2.0),
          status: Position.Open({openedAt: Trade.Timestamp(now +. 1.0)}),
        },
      )
      switch Db.getOpenPositions(getDb()) {
      | Ok(positions) => expect(positions)->toHaveLength(2)
      | Error(_) => expect(true)->toBe(false)
      }
    })
  })

  describe("saveBases / loadBases", () => {
    it("saves and loads bases for a symbol", () => {
      let bases: array<BaseDetector.base> = [
        {
          priceLevel: Trade.Price(100.0),
          bounceCount: Config.BounceCount(3),
          firstSeen: Trade.Timestamp(1000.0),
          lastBounce: Trade.Timestamp(5000.0),
          minLevel: Trade.Price(100.0),
          maxLevel: Trade.Price(100.0),
        },
        {
          priceLevel: Trade.Price(95.0),
          bounceCount: Config.BounceCount(2),
          firstSeen: Trade.Timestamp(2000.0),
          lastBounce: Trade.Timestamp(4000.0),
          minLevel: Trade.Price(95.0),
          maxLevel: Trade.Price(95.0),
        },
      ]
      switch Db.saveBases(getDb(), Trade.Symbol("BTCUSDT"), bases) {
      | Ok() =>
        switch Db.loadBases(getDb(), Trade.Symbol("BTCUSDT")) {
        | Ok(loaded) =>
          expect(loaded)->toHaveLength(2)
          switch loaded[0] {
          | Some(b) =>
            expect(b.priceLevel)->toBe(Trade.Price(100.0))
            expect(b.bounceCount)->toBe(Config.BounceCount(3))
          | None => expect(true)->toBe(false)
          }
        | Error(_) => expect(true)->toBe(false)
        }
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("replaces bases on re-save", () => {
      let _ = Db.saveBases(
        getDb(),
        Trade.Symbol("BTCUSDT"),
        [
          {
            priceLevel: Trade.Price(100.0),
            bounceCount: Config.BounceCount(3),
            firstSeen: Trade.Timestamp(1000.0),
            lastBounce: Trade.Timestamp(5000.0),
            minLevel: Trade.Price(100.0),
            maxLevel: Trade.Price(100.0),
          },
        ],
      )
      let _ = Db.saveBases(
        getDb(),
        Trade.Symbol("BTCUSDT"),
        [
          {
            priceLevel: Trade.Price(200.0),
            bounceCount: Config.BounceCount(1),
            firstSeen: Trade.Timestamp(3000.0),
            lastBounce: Trade.Timestamp(6000.0),
            minLevel: Trade.Price(200.0),
            maxLevel: Trade.Price(200.0),
          },
        ],
      )
      switch Db.loadBases(getDb(), Trade.Symbol("BTCUSDT")) {
      | Ok(loaded) =>
        expect(loaded)->toHaveLength(1)
        switch loaded[0] {
        | Some(b) => expect(b.priceLevel)->toBe(Trade.Price(200.0))
        | None => expect(true)->toBe(false)
        }
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("returns empty for unknown symbol", () => {
      switch Db.loadBases(getDb(), Trade.Symbol("UNKNOWN")) {
      | Ok(loaded) => expect(loaded)->toHaveLength(0)
      | Error(_) => expect(true)->toBe(false)
      }
    })
  })

  describe("saveState / loadState", () => {
    it("saves and loads a key-value pair", () => {
      switch Db.saveState(getDb(), "regime", "Bullish") {
      | Ok() =>
        switch Db.loadState(getDb(), "regime") {
        | Ok(Some(value)) => expect(value)->toBe("Bullish")
        | Ok(None) => expect(true)->toBe(false)
        | Error(_) => expect(true)->toBe(false)
        }
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("overwrites on re-save", () => {
      let _ = Db.saveState(getDb(), "regime", "Bullish")
      let _ = Db.saveState(getDb(), "regime", "Bearish")
      switch Db.loadState(getDb(), "regime") {
      | Ok(Some(value)) => expect(value)->toBe("Bearish")
      | Ok(None) => expect(true)->toBe(false)
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("returns None for unknown key", () => {
      switch Db.loadState(getDb(), "nonexistent") {
      | Ok(None) => expect(true)->toBe(true)
      | Ok(Some(_)) => expect(true)->toBe(false)
      | Error(_) => expect(true)->toBe(false)
      }
    })
  })
})
