// Bot entry point — graceful lifecycle
//
// Startup: load config → open DB → restore state → init exchange + market data → start loop
// Shutdown (SIGINT): stop loop → persist state → print summary → close DB

// Node.js process binding for SIGINT handling
@val @scope("process")
external onSignal: (string, unit => unit) => unit = "on"

@val @scope("process")
external argv: array<string> = "argv"

let run = async () => {
  Logger.info("SPQR Trading Bot starting...")
  Logger.info("Strategy: QFL (Quick Fingers Luc) — Stop-Loss Model")

  // 1. Load config
  let configPath = switch argv[2] {
  | Some(path) => path
  | None => "config.json"
  }
  Logger.info(`Loading config from: ${configPath}`)

  let config = switch BotConfig.load() {
  | Ok(c) => c
  | Error(e) =>
    Logger.error(`Config error: ${BotError.toString(e)}`)
    Logger.error("Usage: node src/Main.res.mjs [config.json]")
    panic("Failed to load config")
  }

  let modeStr = switch config.tradingMode {
  | Config.Paper => "Paper"
  | Config.Live => "Live"
  }
  Logger.info(`Mode: ${modeStr}`)
  Logger.info(`Symbols: ${config.symbols->Array.map(s => { let Trade.Symbol(sym) = s; sym })->Array.join(", ")}`)

  // 2. Open SQLite database
  let dbPath = "spqr_bot.db"
  Logger.info(`Opening database: ${dbPath}`)
  let db = switch Db.open_(dbPath) {
  | Ok(d) => d
  | Error(e) =>
    Logger.error(`Database error: ${BotError.toString(e)}`)
    panic("Failed to open database")
  }

  switch Db.migrate(db) {
  | Ok() => Logger.info("Database migrated")
  | Error(e) =>
    Logger.error(`Migration error: ${BotError.toString(e)}`)
    Db.close(db)
    panic("Failed to migrate database")
  }

  // 3. Restore or create bot state
  let state = switch BotState.restore(db, config.riskLimits) {
  | Ok(s) =>
    Logger.info("Bot state restored from database")
    s
  | Error(_) =>
    Logger.info("Starting with fresh bot state")
    BotState.make(db, config.riskLimits)
  }

  // 4. Initialize exchange
  let exchange = switch PaperExchange.make(config.exchange) {
  | Ok(ex) =>
    Logger.info("Paper exchange initialized ($10,000 starting balance)")
    ex
  | Error(e) =>
    Logger.error(`Exchange error: ${BotError.toString(e)}`)
    Db.close(db)
    panic("Failed to initialize exchange")
  }

  // 5. Initialize market data (CCXT — supports 100+ exchanges)
  let marketData = switch CcxtMarketData.make(config.marketData) {
  | Ok(md) =>
    let Config.Ccxt({exchangeId: Config.ExchangeName(exName)}) = config.marketData.source
    Logger.info(`Market data source initialized (CCXT: ${exName})`)
    md
  | Error(e) =>
    Logger.error(`Market data error: ${BotError.toString(e)}`)
    Db.close(db)
    panic("Failed to initialize market data")
  }

  // 6. Test connectivity
  Logger.info("Testing exchange connectivity...")
  let balanceResult = await PaperExchange.getBalance(exchange)
  switch balanceResult {
  | Ok(balance) =>
    let Config.Balance(bal) = balance
    Logger.info(`Exchange OK — balance: $${bal->Float.toFixed(~digits=2)}`)
  | Error(e) =>
    Logger.error(`Exchange connectivity failed: ${BotError.toString(e)}`)
    Db.close(db)
    panic("Exchange connectivity check failed")
  }

  Logger.info("Testing market data connectivity...")
  let firstSymbol = switch config.symbols[0] {
  | Some(s) => s
  | None =>
    Db.close(db)
    panic("No symbols configured")
  }
  let priceResult = await CcxtMarketData.getCurrentPrice(marketData, firstSymbol)
  switch priceResult {
  | Ok(price) =>
    let Trade.Price(p) = price
    let Trade.Symbol(sym) = firstSymbol
    Logger.info(`Market data OK — ${sym}: $${p->Float.toFixed(~digits=2)}`)
  | Error(e) =>
    Logger.error(`Market data connectivity failed: ${BotError.toString(e)}`)
    Db.close(db)
    panic("Market data connectivity check failed")
  }

  // 7. Create engine
  let Config.PollIntervalMs(intervalMs) = config.engine.pollIntervalMs
  Logger.info(`Poll interval: ${intervalMs->Int.toString}ms`)

  let engine = BotLoop.make(~exchange, ~marketData, ~state, ~config)

  // 8. SIGINT handler for graceful shutdown
  onSignal("SIGINT", () => {
    Logger.info("")
    Logger.info("Received SIGINT — shutting down gracefully...")
    BotLoop.stop(engine)
  })

  Logger.info("=== Bot Ready ===")
  Logger.info("Press Ctrl+C to stop")
  Logger.info("")

  // 9. Start the engine
  await BotLoop.start(engine)

  // 10. Cleanup
  BotState.persist(state)->ignore
  Db.close(db)
  Logger.info("Database closed. Goodbye!")
}

// Execute
let _ = run()
