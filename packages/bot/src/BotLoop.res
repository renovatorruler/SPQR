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
  marketData: CcxtMarketData.t,
  state: BotState.t,
  config: Config.botConfig,
  mutable engineState: engineState,
  mutable tickCount: int,
}

let make = (
  ~exchange: PaperExchange.t,
  ~marketData: CcxtMarketData.t,
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
  let candleResult = await CcxtMarketData.getCandles(
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
    let priceResult = await CcxtMarketData.getCurrentPrice(engine.marketData, symbol)

    switch priceResult {
    | Error(e) =>
      Logger.error(`Failed to get price for ${sym}: ${BotError.toString(e)}`)
      Error(e)
    | Ok(currentPrice) =>
      let Trade.Price(priceVal) = currentPrice
      Logger.debug(`${sym} price: ${priceVal->Float.toFixed(~digits=2)}`)

      // Feed real price to paper exchange for realistic order fills
      PaperExchange.setCurrentPrice(engine.exchange, symbol, currentPrice)

      // 3. Detect bases
      let baseResult = BaseDetector.detectBases(candles, ~config=engine.config.qfl.baseFilter)
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

        // LLM regime check if stale (optional)
        switch engine.config.llm {
        | Some(llmConfig) =>
          if BotState.isRegimeStale(engine.state, llmConfig.regimeCheckIntervalMs) {
            let config = LlmShared.configFromLlmConfig(llmConfig)
            let regimeResult = await LlmService.assessRegime(
              ~provider=Config.Anthropic,
              ~candles,
              ~config,
            )
            switch regimeResult {
            | Ok(regime) =>
              BotState.updateRegime(engine.state, regime)
              Logger.info(`Market regime: ${LlmShared.regimeToString(regime)}`)
            | Error(e) =>
              Logger.error(`LLM regime check failed: ${BotError.toString(e)}`)
            }
          }
        | None => ()
        }

        // Committee setup evaluation
        let proceedToEntry = switch engine.config.qfl.setupEvaluation {
        | Config.Disabled => true
        | Config.Committee(committee) =>
          let evalResult = await LlmCommittee.evaluateSetup(
            ~committee,
            ~symbol,
            ~base,
            ~currentPrice,
            ~crackPercent,
            ~regime=engine.state.regime,
            ~candles,
          )
          switch evalResult {
          | Ok(LlmCommittee.Go({confidence, _})) =>
            let Config.Confidence(c) = confidence
            Logger.info(`${sym}: LLM committee GO (confidence ${c->Float.toFixed(~digits=2)})`)
            true
          | Ok(LlmCommittee.NoGo({confidence, _})) =>
            let Config.Confidence(c) = confidence
            Logger.info(`${sym}: LLM committee NO-GO (confidence ${c->Float.toFixed(~digits=2)})`)
            false
          | Error(e) =>
            Logger.error(`${sym}: LLM committee error — ${BotError.toString(e)}`)
            false
          }
        }

        if proceedToEntry {
          let Trade.Quantity(maxQty) = engine.config.riskLimits.maxPositionSize
          let qty = Trade.Quantity(maxQty /. priceVal)
          let buyResult = await TradeExecutor.executeBuy(
            ~exchange=engine.exchange,
            ~db=engine.state.db,
            ~state=engine.state,
            ~symbol,
            ~currentPrice,
            ~qty,
            ~base,
          )
          switch buyResult {
          | Ok(_) => Ok()
          | Error(e) => Error(e)
          }
        } else {
          Ok()
        }

      | Ok(QflStrategy.BounceBack({entryPrice, _})) =>
        let Trade.Price(entry) = entryPrice
        Logger.info(`${sym}: BOUNCE BACK to base — taking profit (entry: ${entry->Float.toFixed(~digits=2)})`)

        let symbolState = BotState.getSymbolState(engine.state, symbol)
        switch symbolState.openPosition {
        | None => Ok()
        | Some({qty, _}) =>
          let sellResult = await TradeExecutor.executeSell(
            ~exchange=engine.exchange,
            ~db=engine.state.db,
            ~state=engine.state,
            ~symbol,
            ~entryPrice,
            ~currentPrice,
            ~qty,
            ~reason="take profit",
          )
          switch sellResult {
          | Ok(_) => Ok()
          | Error(e) => Error(e)
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
        | Some({qty, _}) =>
          let sellResult = await TradeExecutor.executeSell(
            ~exchange=engine.exchange,
            ~db=engine.state.db,
            ~state=engine.state,
            ~symbol,
            ~entryPrice,
            ~currentPrice,
            ~qty,
            ~reason="stop loss",
          )
          switch sellResult {
          | Ok(_) => Ok()
          | Error(e) => Error(e)
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

  // Persist state — log on failure, don't halt the loop
  switch BotState.persist(engine.state) {
  | Ok() => ()
  | Error(e) => Logger.error(`Failed to persist state: ${BotError.toString(e)}`)
  }

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
    | Error(e) => Logger.error(`Failed to get final balance: ${BotError.toString(e)}`)
    }
  })

  switch Db.getOpenPositions(engine.state.db) {
  | Ok(positions) =>
    Logger.info(`Open positions: ${positions->Array.length->Int.toString}`)
  | Error(e) => Logger.error(`Failed to query open positions: ${BotError.toString(e)}`)
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
