// Bot Loop — main polling orchestration
//
// Each tick:
//   For each symbol:
//     1. Fetch candles + current price from market data
//     2. Run base detection
//     3. Run QFL strategy analysis
//     4. If CrackDetected → LLM evaluate → risk check → place buy
//     5. If BounceBack → place sell (take profit)
//     6. If StopLossTriggered → place sell (stop loss)
//     7. Persist state to SQLite
//   Check risk halt → if halted, stop loop

@val external setTimeout: (unit => unit, int) => float = "setTimeout"

type engineState =
  | Initializing
  | Running
  | ShuttingDown
  | Stopped

type t = {
  exchange: PaperExchange.t,
  marketData: BinanceMarketData.t,
  state: BotState.t,
  config: Config.botConfig,
  mutable engineState: engineState,
  mutable tickCount: int,
}

let make = (
  ~exchange: PaperExchange.t,
  ~marketData: BinanceMarketData.t,
  ~state: BotState.t,
  ~config: Config.botConfig,
): t => {
  {
    exchange,
    marketData,
    state,
    config,
    engineState: Initializing,
    tickCount: 0,
  }
}

// Process a single symbol in one tick
let processSymbol = async (
  engine: t,
  symbol: Trade.symbol,
): result<unit, BotError.t> => {
  let Trade.Symbol(sym) = symbol

  // 1. Fetch candles
  let candleResult = await BinanceMarketData.getCandles(
    engine.marketData,
    ~symbol,
    ~interval=engine.config.marketData.defaultInterval,
    ~limit=engine.config.qfl.lookbackCandles,
  )

  switch candleResult {
  | Error(e) =>
    Logger.error(`Failed to fetch candles for ${sym}: ${BotError.toString(e)}`)
    Error(e)
  | Ok(candles) =>
    // 2. Get current price
    let priceResult = await BinanceMarketData.getCurrentPrice(engine.marketData, symbol)

    switch priceResult {
    | Error(e) =>
      Logger.error(`Failed to get price for ${sym}: ${BotError.toString(e)}`)
      Error(e)
    | Ok(currentPrice) =>
      let Trade.Price(priceVal) = currentPrice
      Logger.debug(`${sym} price: ${priceVal->Float.toFixed(~digits=2)}`)

      // 3. Detect bases
      let baseResult = BaseDetector.detectBases(candles, ~minBounces=engine.config.qfl.minBouncesForBase)
      switch baseResult {
      | BaseDetector.BasesFound({bases}) =>
        BotState.updateBases(engine.state, symbol, bases)
        Logger.debug(`${sym}: ${bases->Array.length->Int.toString} bases detected`)
      | BaseDetector.NoBases =>
        BotState.updateBases(engine.state, symbol, [])
      }

      // 4. Get symbol state for strategy
      let symbolState = BotState.getSymbolState(engine.state, symbol)

      // 5. Run QFL analysis
      let signal = QflStrategy.analyze(
        ~candles,
        ~currentPrice,
        ~symbol,
        ~config=engine.config.qfl,
        ~openPosition=symbolState.openPosition,
      )

      switch signal {
      | Error(e) =>
        Logger.debug(`${sym} strategy error: ${BotError.toString(e)}`)
        Ok()
      | Ok(QflStrategy.NoSignal) =>
        Logger.debug(`${sym}: no signal`)
        Ok()

      | Ok(QflStrategy.CrackDetected({base, crackPercent, _})) =>
        let Config.CrackPercent(crackPct) = crackPercent
        let Trade.Price(baseLevel) = base.priceLevel
        Logger.info(
          `${sym}: CRACK detected! ${crackPct->Float.toFixed(~digits=1)}% below base at ${baseLevel->Float.toFixed(~digits=2)}`,
        )

        // LLM regime check if stale
        switch engine.config.llm {
        | Some(llmConfig) =>
          if BotState.isRegimeStale(engine.state, llmConfig.regimeCheckIntervalMs) {
            let regimeResult = await LlmEvaluator.assessRegime(~candles, ~config=llmConfig)
            switch regimeResult {
            | Ok(regime) =>
              BotState.updateRegime(engine.state, regime)
              Logger.info(`Market regime: ${LlmEvaluator.regimeToString(regime)}`)
            | Error(e) =>
              Logger.error(`LLM regime check failed: ${BotError.toString(e)}`)
            }
          }

          // LLM setup evaluation
          if llmConfig.evaluateSetups {
            let evalResult = await LlmEvaluator.evaluateSetup(
              ~symbol,
              ~base,
              ~currentPrice,
              ~crackPercent,
              ~regime=engine.state.regime,
              ~candles,
              ~config=llmConfig,
            )
            switch evalResult {
            | Ok(LlmEvaluator.Skip({reasoning})) =>
              Logger.info(`${sym}: LLM says SKIP — ${reasoning}`)
              Ok()
            | Ok(LlmEvaluator.Go({reasoning})) =>
              Logger.info(`${sym}: LLM says GO — ${reasoning}`)
              // Proceed to risk check and order placement below
              let Trade.Quantity(maxQty) = engine.config.riskLimits.maxPositionSize
              let qty = Trade.Quantity(maxQty /. priceVal)
              switch RiskManager.checkEntry(engine.state.riskManager, ~qty, ~price=currentPrice) {
              | RiskManager.Blocked(err) =>
                Logger.error(`${sym}: RISK BLOCKED — ${BotError.toString(err)}`)
                Ok()
              | RiskManager.Allowed =>
                let orderResult = await PaperExchange.placeOrder(
                  engine.exchange,
                  ~symbol,
                  ~side=Trade.Buy,
                  ~orderType=Trade.Market,
                  ~qty,
                )
                switch orderResult {
                | Ok(trade) =>
                  Db.insertTrade(engine.state.db, trade)->ignore
                  let pos = Position.make(
                    ~symbol,
                    ~side=Position.Long,
                    ~entryPrice=currentPrice,
                    ~qty,
                    ~openedAt=Trade.Timestamp(Date.now()),
                  )
                  Db.insertPosition(engine.state.db, pos)->ignore
                  RiskManager.recordOpen(engine.state.riskManager)
                  BotState.setOpenPosition(
                    engine.state,
                    symbol,
                    Some({entryPrice: currentPrice, base}),
                  )
                  Logger.trade(`${sym}: BUY executed`)
                  Ok()
                | Error(e) =>
                  Logger.error(`${sym}: Order failed — ${BotError.toString(e)}`)
                  Error(e)
                }
              }
            | Error(e) =>
              Logger.error(`${sym}: LLM eval failed: ${BotError.toString(e)}`)
              // Fall through without LLM — still place the trade
              Ok()
            }
          } else {
            // LLM setup eval disabled — go straight to risk check
            let Trade.Quantity(maxQty) = engine.config.riskLimits.maxPositionSize
            let qty = Trade.Quantity(maxQty /. priceVal)
            switch RiskManager.checkEntry(engine.state.riskManager, ~qty, ~price=currentPrice) {
            | RiskManager.Blocked(err) =>
              Logger.error(`${sym}: RISK BLOCKED — ${BotError.toString(err)}`)
              Ok()
            | RiskManager.Allowed =>
              let orderResult = await PaperExchange.placeOrder(
                engine.exchange,
                ~symbol,
                ~side=Trade.Buy,
                ~orderType=Trade.Market,
                ~qty,
              )
              switch orderResult {
              | Ok(trade) =>
                Db.insertTrade(engine.state.db, trade)->ignore
                let pos = Position.make(
                  ~symbol,
                  ~side=Position.Long,
                  ~entryPrice=currentPrice,
                  ~qty,
                  ~openedAt=Trade.Timestamp(Date.now()),
                )
                Db.insertPosition(engine.state.db, pos)->ignore
                RiskManager.recordOpen(engine.state.riskManager)
                BotState.setOpenPosition(
                  engine.state,
                  symbol,
                  Some({entryPrice: currentPrice, base}),
                )
                Logger.trade(`${sym}: BUY executed`)
                Ok()
              | Error(e) =>
                Logger.error(`${sym}: Order failed — ${BotError.toString(e)}`)
                Error(e)
              }
            }
          }
        | None =>
          // No LLM config — go straight to risk check and order
          let Trade.Quantity(maxQty) = engine.config.riskLimits.maxPositionSize
          let qty = Trade.Quantity(maxQty /. priceVal)
          switch RiskManager.checkEntry(engine.state.riskManager, ~qty, ~price=currentPrice) {
          | RiskManager.Blocked(err) =>
            Logger.error(`${sym}: RISK BLOCKED — ${BotError.toString(err)}`)
            Ok()
          | RiskManager.Allowed =>
            let orderResult = await PaperExchange.placeOrder(
              engine.exchange,
              ~symbol,
              ~side=Trade.Buy,
              ~orderType=Trade.Market,
              ~qty,
            )
            switch orderResult {
            | Ok(trade) =>
              Db.insertTrade(engine.state.db, trade)->ignore
              let pos = Position.make(
                ~symbol,
                ~side=Position.Long,
                ~entryPrice=currentPrice,
                ~qty,
                ~openedAt=Trade.Timestamp(Date.now()),
              )
              Db.insertPosition(engine.state.db, pos)->ignore
              RiskManager.recordOpen(engine.state.riskManager)
              BotState.setOpenPosition(
                engine.state,
                symbol,
                Some({entryPrice: currentPrice, base}),
              )
              Logger.trade(`${sym}: BUY executed`)
              Ok()
            | Error(e) =>
              Logger.error(`${sym}: Order failed — ${BotError.toString(e)}`)
              Error(e)
            }
          }
        }

      | Ok(QflStrategy.BounceBack({entryPrice, _})) =>
        let Trade.Price(entry) = entryPrice
        Logger.info(`${sym}: BOUNCE BACK to base — taking profit (entry: ${entry->Float.toFixed(~digits=2)})`)

        let symbolState = BotState.getSymbolState(engine.state, symbol)
        switch symbolState.openPosition {
        | None => Ok()
        | Some(_) =>
          // Find position quantity from database
          let qtyOpt = switch Db.getOpenPositions(engine.state.db) {
          | Ok(positions) =>
            positions
            ->Array.find(p => p.symbol == symbol)
            ->Option.map(p => p.currentQty)
          | Error(_) => None
          }

          switch qtyOpt {
          | None =>
            Logger.error(`${sym}: No position quantity found — clearing state`)
            BotState.setOpenPosition(engine.state, symbol, None)
            Ok()
          | Some(qty) =>
            let orderResult = await PaperExchange.placeOrder(
              engine.exchange,
              ~symbol,
              ~side=Trade.Sell,
              ~orderType=Trade.Market,
              ~qty,
            )
            switch orderResult {
            | Ok(trade) =>
              Db.insertTrade(engine.state.db, trade)->ignore
              let pnl = Position.computePnl(
                ~side=Position.Long,
                ~entryPrice,
                ~currentPrice,
                ~qty,
              )
              RiskManager.recordClose(engine.state.riskManager, pnl)
              BotState.setOpenPosition(engine.state, symbol, None)
              let Position.Pnl(pnlVal) = pnl
              Logger.trade(`${sym}: SELL (take profit) PnL: ${pnlVal->Float.toFixed(~digits=2)}`)
              Ok()
            | Error(e) =>
              Logger.error(`${sym}: Sell failed — ${BotError.toString(e)}`)
              Error(e)
            }
          }
        }

      | Ok(QflStrategy.StopLossTriggered({entryPrice, lossPercent: Config.StopLossPercent(lossPct), _})) =>
        let Trade.Price(entry) = entryPrice
        Logger.info(
          `${sym}: STOP LOSS triggered — ${lossPct->Float.toFixed(~digits=1)}% loss (entry: ${entry->Float.toFixed(~digits=2)})`,
        )

        let symbolState = BotState.getSymbolState(engine.state, symbol)
        switch symbolState.openPosition {
        | None => Ok()
        | Some(_) =>
          let qtyOpt = switch Db.getOpenPositions(engine.state.db) {
          | Ok(positions) =>
            positions
            ->Array.find(p => p.symbol == symbol)
            ->Option.map(p => p.currentQty)
          | Error(_) => None
          }

          switch qtyOpt {
          | None =>
            Logger.error(`${sym}: No position quantity found — clearing state`)
            BotState.setOpenPosition(engine.state, symbol, None)
            Ok()
          | Some(qty) =>
            let orderResult = await PaperExchange.placeOrder(
              engine.exchange,
              ~symbol,
              ~side=Trade.Sell,
              ~orderType=Trade.Market,
              ~qty,
            )
            switch orderResult {
            | Ok(trade) =>
              Db.insertTrade(engine.state.db, trade)->ignore
              let pnl = Position.computePnl(
                ~side=Position.Long,
                ~entryPrice,
                ~currentPrice,
                ~qty,
              )
              RiskManager.recordClose(engine.state.riskManager, pnl)
              BotState.setOpenPosition(engine.state, symbol, None)
              let Position.Pnl(pnlVal) = pnl
              Logger.trade(
                `${sym}: SELL (stop loss) PnL: ${pnlVal->Float.toFixed(~digits=2)} — waiting for new channel`,
              )
              Ok()
            | Error(e) =>
              Logger.error(`${sym}: Stop loss sell failed — ${BotError.toString(e)}`)
              Error(e)
            }
          }
        }
      }
    }
  }
}

// Run a single tick — process all symbols
let tick = async (engine: t): result<unit, BotError.t> => {
  engine.tickCount = engine.tickCount + 1
  Logger.debug(`--- Tick #${engine.tickCount->Int.toString} ---`)

  // Process each symbol sequentially (rate limiting consideration)
  let symbols = engine.config.symbols
  // Justification for for-loop: sequential async to avoid rate limiting on exchange API
  for i in 0 to symbols->Array.length - 1 {
    switch symbols[i] {
    | Some(symbol) =>
      let _ = await processSymbol(engine, symbol)
    | None => ()
    }
  }

  // Check risk halt
  if RiskManager.isHalted(engine.state.riskManager) {
    Logger.error("RISK HALT — bot stopping due to risk limits")
    engine.engineState = ShuttingDown
  }

  // Persist state
  BotState.persist(engine.state)->ignore

  Ok()
}

// Main loop — runs tick every pollIntervalMs
let rec runLoop = async (engine: t): unit => {
  switch engine.engineState {
  | Running =>
    let _ = await tick(engine)
    switch engine.engineState {
    | Running =>
      let Config.PollIntervalMs(intervalMs) = engine.config.engine.pollIntervalMs
      await Promise.make((resolve, _reject) => {
        setTimeout(() => resolve(.), intervalMs)->ignore
      })
      await runLoop(engine)
    | _ => ()
    }
  | _ => ()
  }
}

let stop = (engine: t): unit => {
  engine.engineState = ShuttingDown
}

// Print shutdown summary
let printSummary = (engine: t): unit => {
  Logger.info("=== Shutdown Summary ===")
  Logger.info(`Ticks completed: ${engine.tickCount->Int.toString}`)

  let balanceResult = PaperExchange.getBalance(engine.exchange)
  let _ = balanceResult->Promise.thenResolve(result => {
    switch result {
    | Ok(balance) =>
      let Config.Balance(bal) = balance
      Logger.info(`Final balance: $${bal->Float.toFixed(~digits=2)}`)
    | Error(_) => ()
    }
  })

  let posResult = Db.getOpenPositions(engine.state.db)
  switch posResult {
  | Ok(positions) =>
    Logger.info(`Open positions: ${positions->Array.length->Int.toString}`)
  | Error(_) => ()
  }
}

// Start the engine
let start = async (engine: t): unit => {
  engine.engineState = Running
  Logger.info("Bot engine started — entering main loop")

  await runLoop(engine)

  // Shutdown
  engine.engineState = Stopped
  printSummary(engine)
  Logger.info("Bot engine stopped")
}
