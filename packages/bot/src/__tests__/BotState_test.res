open Vitest

let dbRef: ref<option<Db.t>> = ref(None)
let getDb = () => dbRef.contents->Option.getOrThrow

let riskLimits: Config.riskLimits = {
  maxPositionSize: Trade.Quantity(10000.0),
  maxOpenPositions: Config.MaxOpenPositions(3),
  maxDailyLoss: Position.Pnl(500.0),
}

beforeEach(() => {
  switch Db.open_(":memory:") {
  | Ok(db) =>
    dbRef := Some(db)
    Db.migrate(db)->ignore
  | Error(_) => expect(true)->toBe(false)
  }
})

afterEach(() => {
  Db.close(getDb())
})

describe("BotState", () => {
  describe("make", () => {
    it("creates state with empty symbol states", () => {
      let state = BotState.make(getDb(), riskLimits)
      switch state.regime {
      | Unknown => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
      switch state.lastRegimeCheck {
      | None => expect(true)->toBe(true)
      | Some(_) => expect(true)->toBe(false)
      }
      expect(state.symbolStates->Dict.keysToArray->Array.length)->toBe(0)
    })

    it("initializes risk manager", () => {
      let state = BotState.make(getDb(), riskLimits)
      expect(RiskManager.isHalted(state.riskManager))->toBe(false)
    })
  })

  describe("getSymbolState", () => {
    it("creates default state for new symbol", () => {
      let state = BotState.make(getDb(), riskLimits)
      let ss = BotState.getSymbolState(state, Trade.Symbol("BTCUSDT"))
      expect(ss.bases->Array.length)->toBe(0)
      switch ss.openPosition {
      | None => expect(true)->toBe(true)
      | Some(_) => expect(true)->toBe(false)
      }
    })

    it("returns same state on subsequent calls", () => {
      let state = BotState.make(getDb(), riskLimits)
      let ss1 = BotState.getSymbolState(state, Trade.Symbol("BTCUSDT"))
      let ss2 = BotState.getSymbolState(state, Trade.Symbol("BTCUSDT"))
      expect(ss1 === ss2)->toBe(true)
    })

    it("isolates state per symbol", () => {
      let state = BotState.make(getDb(), riskLimits)
      let btc = BotState.getSymbolState(state, Trade.Symbol("BTCUSDT"))
      let eth = BotState.getSymbolState(state, Trade.Symbol("ETHUSDT"))
      expect(btc === eth)->toBe(false)
    })
  })

  describe("updateBases", () => {
    it("updates bases for a symbol", () => {
      let state = BotState.make(getDb(), riskLimits)
      let bases: array<BaseDetector.base> = [
        {
          priceLevel: Trade.Price(100.0),
          bounceCount: Config.BounceCount(3),
          firstSeen: Trade.Timestamp(1000.0),
          lastBounce: Trade.Timestamp(5000.0),
          minLevel: Trade.Price(100.0),
          maxLevel: Trade.Price(100.0),
        },
      ]
      BotState.updateBases(state, Trade.Symbol("BTCUSDT"), bases)
      let ss = BotState.getSymbolState(state, Trade.Symbol("BTCUSDT"))
      expect(ss.bases->Array.length)->toBe(1)
      let base = ss.bases[0]->Option.getOrThrow
      let Trade.Price(level) = base.priceLevel
      expect(level)->toBe(100.0)
    })

    it("persists bases to database", () => {
      let state = BotState.make(getDb(), riskLimits)
      BotState.updateBases(
        state,
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
      switch Db.loadBases(getDb(), Trade.Symbol("BTCUSDT")) {
      | Ok(loaded) => expect(loaded->Array.length)->toBe(1)
      | Error(_) => expect(true)->toBe(false)
      }
    })
  })

  describe("setOpenPosition", () => {
    it("sets position info for a symbol", () => {
      let state = BotState.make(getDb(), riskLimits)
      let posInfo: QflStrategy.openPositionInfo = {
        entryPrice: Trade.Price(50000.0),
        base: {
          priceLevel: Trade.Price(48000.0),
          bounceCount: Config.BounceCount(3),
          firstSeen: Trade.Timestamp(1000.0),
          lastBounce: Trade.Timestamp(5000.0),
          minLevel: Trade.Price(48000.0),
          maxLevel: Trade.Price(48000.0),
        },
      }
      BotState.setOpenPosition(state, Trade.Symbol("BTCUSDT"), Some(posInfo))
      let ss = BotState.getSymbolState(state, Trade.Symbol("BTCUSDT"))
      switch ss.openPosition {
      | Some(pos) =>
        let Trade.Price(entry) = pos.entryPrice
        expect(entry)->toBe(50000.0)
      | None => expect(true)->toBe(false)
      }
    })

    it("clears position when set to None", () => {
      let state = BotState.make(getDb(), riskLimits)
      BotState.setOpenPosition(
        state,
        Trade.Symbol("BTCUSDT"),
        Some({
          entryPrice: Trade.Price(50000.0),
          base: {
            priceLevel: Trade.Price(48000.0),
            bounceCount: Config.BounceCount(3),
            firstSeen: Trade.Timestamp(1000.0),
            lastBounce: Trade.Timestamp(5000.0),
            minLevel: Trade.Price(48000.0),
            maxLevel: Trade.Price(48000.0),
          },
        }),
      )
      BotState.setOpenPosition(state, Trade.Symbol("BTCUSDT"), None)
      let ss = BotState.getSymbolState(state, Trade.Symbol("BTCUSDT"))
      switch ss.openPosition {
      | None => expect(true)->toBe(true)
      | Some(_) => expect(true)->toBe(false)
      }
    })
  })

  describe("updateRegime", () => {
    it("updates regime and timestamp", () => {
      let state = BotState.make(getDb(), riskLimits)
      let before = Date.now()
      BotState.updateRegime(state, LlmEvaluator.TrendingUp({confidence: Config.Confidence(0.8)}))
      switch state.regime {
      | TrendingUp(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
      switch state.lastRegimeCheck {
      | Some(Trade.Timestamp(ts)) => expect(ts)->toBeGreaterThanOrEqual(before)
      | None => expect(true)->toBe(false)
      }
    })

    it("persists regime to database", () => {
      let state = BotState.make(getDb(), riskLimits)
      BotState.updateRegime(
        state,
        LlmEvaluator.TrendingDown({confidence: Config.Confidence(0.7)}),
      )
      switch Db.loadState(getDb(), "regime") {
      | Ok(Some(value)) => expect(value)->toBe("Trending Down (0.7)")
      | _ => expect(true)->toBe(false)
      }
    })
  })

  describe("isRegimeStale", () => {
    it("returns true when never checked", () => {
      let state = BotState.make(getDb(), riskLimits)
      expect(BotState.isRegimeStale(state, Config.IntervalMs(60000)))->toBe(true)
    })

    it("returns false immediately after update", () => {
      let state = BotState.make(getDb(), riskLimits)
      BotState.updateRegime(
        state,
        LlmEvaluator.TrendingUp({confidence: Config.Confidence(0.8)}),
      )
      expect(BotState.isRegimeStale(state, Config.IntervalMs(60000)))->toBe(false)
    })
  })

  describe("restore", () => {
    it("restores state from database with open positions", () => {
      let now = Date.now()
      Db.insertPosition(
        getDb(),
        {
          symbol: Trade.Symbol("BTCUSDT"),
          side: Position.Long,
          entryPrice: Trade.Price(50000.0),
          currentQty: Trade.Quantity(0.5),
          status: Position.Open({openedAt: Trade.Timestamp(now)}),
        },
      )->ignore

      switch BotState.restore(getDb(), riskLimits) {
      | Ok(state) =>
        let ss = BotState.getSymbolState(state, Trade.Symbol("BTCUSDT"))
        switch ss.openPosition {
        | Some(pos) =>
          let Trade.Price(entry) = pos.entryPrice
          expect(entry)->toBe(50000.0)
        | None => expect(true)->toBe(false)
        }
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("restores empty state when no positions", () => {
      switch BotState.restore(getDb(), riskLimits) {
      | Ok(state) =>
        expect(state.symbolStates->Dict.keysToArray->Array.length)->toBe(0)
      | Error(_) => expect(true)->toBe(false)
      }
    })
  })

  describe("persist", () => {
    it("saves current regime to database", () => {
      let state = BotState.make(getDb(), riskLimits)
      state.regime = LlmEvaluator.HighVolatility({confidence: Config.Confidence(0.9)})
      BotState.persist(state)->ignore
      switch Db.loadState(getDb(), "regime") {
      | Ok(Some(value)) => expect(value)->toBe("High Volatility (0.9)")
      | _ => expect(true)->toBe(false)
      }
    })
  })
})
