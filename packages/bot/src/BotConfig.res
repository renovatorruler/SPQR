// Bot-specific config loader (Decision #5)
// Loads config.json, decodes into Config.botConfig, fails fast on errors.

// Node.js fs binding for reading config files
@module("node:fs") external readFileSync: (string, string) => string = "readFileSync"

let decodeExchangeId = (s: string): option<Config.exchangeId> => {
  switch s {
  | "binance" => Some(Binance)
  | "uniswap" => Some(Uniswap)
  | "jupiter" => Some(Jupiter)
  | "paper" => Some(PaperExchange)
  | _ => None
  }
}

let decodeTradingMode = (s: string): option<Config.tradingMode> => {
  switch s {
  | "paper" => Some(Paper)
  | "live" => Some(Live)
  | _ => None
  }
}

let decodeExchangeConfig = (obj: Dict.t<JSON.t>): result<Config.exchangeConfig, BotError.t> => {
  let exchangeIdStr =
    obj->Dict.get("exchangeId")->Option.flatMap(JSON.Decode.string)

  switch exchangeIdStr {
  | None =>
    Error(BotError.ConfigError(MissingField({fieldName: "exchange.exchangeId"})))
  | Some(idStr) =>
    switch decodeExchangeId(idStr) {
    | None =>
      Error(
        BotError.ConfigError(
          InvalidValue({
            fieldName: "exchange.exchangeId",
            given: idStr,
            expected: "binance | uniswap | jupiter | paper",
          }),
        ),
      )
    | Some(exchangeId) =>
      let baseUrl =
        obj
        ->Dict.get("baseUrl")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.map(s => Config.BaseUrl(s))
      let apiKey =
        obj
        ->Dict.get("apiKey")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.map(s => Config.ApiKey(s))
      let apiSecret =
        obj
        ->Dict.get("apiSecret")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.map(s => Config.ApiSecret(s))
      Ok({
        Config.exchangeId,
        baseUrl,
        apiKey,
        apiSecret,
      })
    }
  }
}

let decodeRiskLimits = (obj: Dict.t<JSON.t>): result<Config.riskLimits, BotError.t> => {
  let maxPositionSize =
    obj->Dict.get("maxPositionSize")->Option.flatMap(JSON.Decode.float)
  let maxOpenPositions =
    obj
    ->Dict.get("maxOpenPositions")
    ->Option.flatMap(JSON.Decode.float)
    ->Option.map(Float.toInt)
  let maxDailyLoss =
    obj->Dict.get("maxDailyLoss")->Option.flatMap(JSON.Decode.float)

  switch (maxPositionSize, maxOpenPositions, maxDailyLoss) {
  | (Some(mps), Some(mop), Some(mdl)) =>
    Ok({
      Config.maxPositionSize: Trade.Quantity(mps),
      maxOpenPositions: mop,
      maxDailyLoss: Position.Pnl(mdl),
    })
  | (None, _, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "riskLimits.maxPositionSize"})))
  | (_, None, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "riskLimits.maxOpenPositions"})))
  | (_, _, None) =>
    Error(BotError.ConfigError(MissingField({fieldName: "riskLimits.maxDailyLoss"})))
  }
}

let decodeSymbols = (arr: array<JSON.t>): result<array<Trade.symbol>, BotError.t> => {
  let symbols = arr->Array.filterMap(JSON.Decode.string)
  if symbols->Array.length != arr->Array.length {
    Error(BotError.ConfigError(InvalidValue({
      fieldName: "symbols",
      given: "non-string values",
      expected: "array of strings",
    })))
  } else {
    Ok(symbols->Array.map(s => Trade.Symbol(s)))
  }
}

let decodeQflConfig = (obj: Dict.t<JSON.t>): result<Config.qflConfig, BotError.t> => {
  let crackThreshold = obj->Dict.get("crackThreshold")->Option.flatMap(JSON.Decode.float)
  let stopLossThreshold = obj->Dict.get("stopLossThreshold")->Option.flatMap(JSON.Decode.float)
  let takeProfitTarget = obj->Dict.get("takeProfitTarget")->Option.flatMap(JSON.Decode.float)
  let minBouncesForBase =
    obj
    ->Dict.get("minBouncesForBase")
    ->Option.flatMap(JSON.Decode.float)
    ->Option.map(Float.toInt)
  let lookbackCandles =
    obj
    ->Dict.get("lookbackCandles")
    ->Option.flatMap(JSON.Decode.float)
    ->Option.map(Float.toInt)

  switch (crackThreshold, stopLossThreshold, takeProfitTarget, minBouncesForBase, lookbackCandles) {
  | (Some(ct), Some(sl), Some(tp), Some(mb), Some(lb)) =>
    Ok({
      Config.crackThreshold: Config.CrackPercent(ct),
      stopLossThreshold: Config.StopLossPercent(sl),
      takeProfitTarget: Config.TakeProfitPercent(tp),
      minBouncesForBase: Config.BounceCount(mb),
      lookbackCandles: Config.CandleCount(lb),
    })
  | (None, _, _, _, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "qfl.crackThreshold"})))
  | (_, None, _, _, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "qfl.stopLossThreshold"})))
  | (_, _, None, _, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "qfl.takeProfitTarget"})))
  | (_, _, _, None, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "qfl.minBouncesForBase"})))
  | (_, _, _, _, None) =>
    Error(BotError.ConfigError(MissingField({fieldName: "qfl.lookbackCandles"})))
  }
}

let decodeLlmConfig = (obj: Dict.t<JSON.t>): result<Config.llmConfig, BotError.t> => {
  let apiKey = obj->Dict.get("apiKey")->Option.flatMap(JSON.Decode.string)
  let model = obj->Dict.get("model")->Option.flatMap(JSON.Decode.string)
  let regimeCheckIntervalMs =
    obj
    ->Dict.get("regimeCheckIntervalMs")
    ->Option.flatMap(JSON.Decode.float)
    ->Option.map(Float.toInt)
  let evaluateSetups = obj->Dict.get("evaluateSetups")->Option.flatMap(JSON.Decode.bool)

  switch (apiKey, model, regimeCheckIntervalMs, evaluateSetups) {
  | (Some(ak), Some(m), Some(ri), Some(es)) =>
    Ok({
      Config.apiKey: Config.LlmApiKey(ak),
      model: Config.LlmModel(m),
      regimeCheckIntervalMs: Config.IntervalMs(ri),
      evaluateSetups: es,
    })
  | (None, _, _, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "llm.apiKey"})))
  | (_, None, _, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "llm.model"})))
  | (_, _, None, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "llm.regimeCheckIntervalMs"})))
  | (_, _, _, None) =>
    Error(BotError.ConfigError(MissingField({fieldName: "llm.evaluateSetups"})))
  }
}

let decodeMarketDataConfig = (obj: Dict.t<JSON.t>): result<Config.marketDataConfig, BotError.t> => {
  let source = obj->Dict.get("source")->Option.flatMap(JSON.Decode.string)
  let defaultInterval = obj->Dict.get("defaultInterval")->Option.flatMap(JSON.Decode.string)

  switch (source, defaultInterval) {
  | (Some(src), Some(ivl)) =>
    let marketDataSource = switch src {
    | "binance" => Ok(Config.BinancePublic)
    | other =>
      Error(
        BotError.ConfigError(
          InvalidValue({
            fieldName: "marketData.source",
            given: other,
            expected: "binance",
          }),
        ),
      )
    }
    marketDataSource->Result.map(s => {
      Config.source: s,
      defaultInterval: Config.Interval(ivl),
    })
  | (None, _) =>
    Error(BotError.ConfigError(MissingField({fieldName: "marketData.source"})))
  | (_, None) =>
    Error(BotError.ConfigError(MissingField({fieldName: "marketData.defaultInterval"})))
  }
}

let decodeEngineConfig = (obj: Dict.t<JSON.t>): result<Config.engineConfig, BotError.t> => {
  let pollIntervalMs =
    obj
    ->Dict.get("pollIntervalMs")
    ->Option.flatMap(JSON.Decode.float)
    ->Option.map(Float.toInt)
    ->Option.getOr(30000)
  let closeOnShutdown =
    obj
    ->Dict.get("closeOnShutdown")
    ->Option.flatMap(JSON.Decode.bool)
    ->Option.getOr(false)

  Ok({
    Config.pollIntervalMs: Config.PollIntervalMs(pollIntervalMs),
    closeOnShutdown,
  })
}

let decode = (json: JSON.t): result<Config.botConfig, BotError.t> => {
  switch json->JSON.Decode.object {
  | None => Error(BotError.ConfigError(ParseFailed({message: "Expected JSON object"})))
  | Some(root) =>
    let tradingModeStr =
      root->Dict.get("tradingMode")->Option.flatMap(JSON.Decode.string)
    switch tradingModeStr {
    | None =>
      Error(BotError.ConfigError(MissingField({fieldName: "tradingMode"})))
    | Some(modeStr) =>
      switch decodeTradingMode(modeStr) {
      | None =>
        Error(
          BotError.ConfigError(
            InvalidValue({
              fieldName: "tradingMode",
              given: modeStr,
              expected: "paper | live",
            }),
          ),
        )
      | Some(tradingMode) =>
        let exchangeObj =
          root->Dict.get("exchange")->Option.flatMap(JSON.Decode.object)
        switch exchangeObj {
        | None =>
          Error(BotError.ConfigError(MissingField({fieldName: "exchange"})))
        | Some(exObj) =>
          switch decodeExchangeConfig(exObj) {
          | Error(e) => Error(e)
          | Ok(exchange) =>
            let symbolsArr =
              root->Dict.get("symbols")->Option.flatMap(JSON.Decode.array)
            switch symbolsArr {
            | None =>
              Error(BotError.ConfigError(MissingField({fieldName: "symbols"})))
            | Some(symArr) =>
              switch decodeSymbols(symArr) {
              | Error(e) => Error(e)
              | Ok(symbols) =>
                let riskObj =
                  root->Dict.get("riskLimits")->Option.flatMap(JSON.Decode.object)
                switch riskObj {
                | None =>
                  Error(BotError.ConfigError(MissingField({fieldName: "riskLimits"})))
                | Some(rlObj) =>
                  switch decodeRiskLimits(rlObj) {
                  | Error(e) => Error(e)
                  | Ok(riskLimits) =>
                    // Decode QFL config
                    let qflObj =
                      root->Dict.get("qfl")->Option.flatMap(JSON.Decode.object)
                    switch qflObj {
                    | None =>
                      Error(BotError.ConfigError(MissingField({fieldName: "qfl"})))
                    | Some(qObj) =>
                      switch decodeQflConfig(qObj) {
                      | Error(e) => Error(e)
                      | Ok(qfl) =>
                        // Decode optional LLM config
                        let llm = switch root
                        ->Dict.get("llm")
                        ->Option.flatMap(JSON.Decode.object) {
                        | None => Ok(None)
                        | Some(lObj) => decodeLlmConfig(lObj)->Result.map(c => Some(c))
                        }
                        switch llm {
                        | Error(e) => Error(e)
                        | Ok(llmConfig) =>
                          // Decode market data config
                          let mdObj =
                            root
                            ->Dict.get("marketData")
                            ->Option.flatMap(JSON.Decode.object)
                          switch mdObj {
                          | None =>
                            Error(
                              BotError.ConfigError(
                                MissingField({fieldName: "marketData"}),
                              ),
                            )
                          | Some(mObj) =>
                            switch decodeMarketDataConfig(mObj) {
                            | Error(e) => Error(e)
                            | Ok(marketData) =>
                              // Decode engine config (with defaults)
                              let engineObj =
                                root
                                ->Dict.get("engine")
                                ->Option.flatMap(JSON.Decode.object)
                                ->Option.getOr(Dict.make())
                              switch decodeEngineConfig(engineObj) {
                              | Error(e) => Error(e)
                              | Ok(engine) =>
                                Ok({
                                  Config.tradingMode,
                                  exchange,
                                  symbols,
                                  riskLimits,
                                  qfl,
                                  llm: llmConfig,
                                  marketData,
                                  engine,
                                })
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

let loadFromFile = (path: string): result<Config.botConfig, BotError.t> => {
  try {
    let content = readFileSync(path, "utf-8")
    let json = try {
      Ok(JSON.parseOrThrow(content))
    } catch {
    | JsExn(jsExn) =>
      let msg = jsExn->JsExn.message->Option.getOr("Invalid JSON")
      Error(BotError.ConfigError(ParseFailed({message: msg})))
    | _ =>
      Error(BotError.ConfigError(ParseFailed({message: "Invalid JSON"})))
    }
    json->Result.flatMap(decode)
  } catch {
  | JsExn(jsExn) =>
    let msg = jsExn->JsExn.message->Option.getOr("Unknown error")
    Error(BotError.ConfigError(FileNotFound({path: `${path}: ${msg}`})))
  | _ =>
    Error(BotError.ConfigError(FileNotFound({path: `${path}: Unknown error`})))
  }
}
