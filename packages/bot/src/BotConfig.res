// Bot-specific config loader (Decision #5)
// Loads config.json, decodes into Config.botConfig, fails fast on errors.

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

let decode = (json: JSON.t): result<Config.botConfig, BotError.t> => {
  switch json->JSON.Decode.object {
  | None => Error(BotError.ConfigError(ParseFailed({message: "Expected JSON object"})))
  | Some(root) =>
    // Decode tradingMode
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
        // Decode exchange
        let exchangeObj =
          root->Dict.get("exchange")->Option.flatMap(JSON.Decode.object)
        switch exchangeObj {
        | None =>
          Error(BotError.ConfigError(MissingField({fieldName: "exchange"})))
        | Some(exObj) =>
          switch decodeExchangeConfig(exObj) {
          | Error(e) => Error(e)
          | Ok(exchange) =>
            // Decode symbols
            let symbolsArr =
              root->Dict.get("symbols")->Option.flatMap(JSON.Decode.array)
            switch symbolsArr {
            | None =>
              Error(BotError.ConfigError(MissingField({fieldName: "symbols"})))
            | Some(symArr) =>
              switch decodeSymbols(symArr) {
              | Error(e) => Error(e)
              | Ok(symbols) =>
                // Decode riskLimits
                let riskObj =
                  root->Dict.get("riskLimits")->Option.flatMap(JSON.Decode.object)
                switch riskObj {
                | None =>
                  Error(
                    BotError.ConfigError(MissingField({fieldName: "riskLimits"})),
                  )
                | Some(rlObj) =>
                  decodeRiskLimits(rlObj)->Result.map(riskLimits => {
                    Config.tradingMode,
                    exchange,
                    symbols,
                    riskLimits,
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

let loadFromFile = async (path: string): result<Config.botConfig, BotError.t> => {
  // Note: Node.js file reading would go here.
  // For now, this is a placeholder that documents the intended API.
  let _ = path
  Error(BotError.ConfigError(FileNotFound({path: path})))
}
