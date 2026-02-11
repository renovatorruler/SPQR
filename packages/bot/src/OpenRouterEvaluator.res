// OpenRouter evaluator — OpenAI-compatible chat completions

type fetchHeaders = {
  @as("Content-Type") contentType: string,
  @as("Authorization") authorization: string,
  @as("HTTP-Referer") httpReferer: string,
  @as("X-Title") xTitle: string,
}

type fetchOptions = {
  method: string,
  headers: fetchHeaders,
  body: string,
}

@val external fetch: (string, fetchOptions) => promise<'response> = "fetch"
@send external json: 'response => promise<JSON.t> = "json"
@get external ok: 'response => bool = "ok"
@get external statusText: 'response => string = "statusText"

let buildRequestBody = (
  ~model: Config.llmModelId,
  ~systemPrompt: string,
  ~userPrompt: string,
): JSON.t => {
  let Config.LlmModelId(modelStr) = model
  let messages = [
    Dict.fromArray([
      ("role", "system"->JSON.Encode.string),
      ("content", systemPrompt->JSON.Encode.string),
    ])->JSON.Encode.object,
    Dict.fromArray([
      ("role", "user"->JSON.Encode.string),
      ("content", userPrompt->JSON.Encode.string),
    ])->JSON.Encode.object,
  ]

  Dict.fromArray([
    ("model", modelStr->JSON.Encode.string),
    ("temperature", 0.2->JSON.Encode.float),
    ("messages", messages->JSON.Encode.array),
  ])->JSON.Encode.object
}

let extractResponseText = (json: JSON.t): option<string> => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get("choices"))
  ->Option.flatMap(JSON.Decode.array)
  ->Option.flatMap(arr => arr[0])
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(obj => obj->Dict.get("message"))
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(obj => obj->Dict.get("content"))
  ->Option.flatMap(JSON.Decode.string)
}

let callOpenRouter = async (
  ~member: Config.llmMember,
  ~systemPrompt: string,
  ~userPrompt: string,
): result<string, BotError.t> => {
  let Config.LlmApiKey(apiKey) = member.apiKey
  let Config.LlmBaseUrl(baseUrl) = member.apiBase
  let body = buildRequestBody(~model=member.modelId, ~systemPrompt, ~userPrompt)

  try {
    let response = await fetch(
      `${baseUrl}/chat/completions`,
      {
        method: "POST",
        headers: {
          contentType: "application/json",
          authorization: `Bearer ${apiKey}`,
          httpReferer: "https://spqr.local",
          xTitle: "SPQR Trading Bot",
        },
        body: body->JSON.stringify,
      },
    )

    if !ok(response) {
      Error(BotError.LlmError(ApiCallFailed({message: statusText(response)})))
    } else {
      let jsonData = await json(response)
      switch extractResponseText(jsonData) {
      | Some(text) => Ok(text)
      | None => Error(BotError.LlmError(InvalidLlmResponse({message: "Could not extract text from response"})))
      }
    }
  } catch {
  | JsExn(jsExn) =>
    let msg = jsExn->JsExn.message->Option.getOr("Unknown error")
    Error(BotError.LlmError(ApiCallFailed({message: msg})))
  | _ =>
    Error(BotError.LlmError(ApiCallFailed({message: "Unknown error"})))
  }
}

let evaluateSetup = async (
  ~member: Config.llmMember,
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: LlmEvaluator.marketRegime,
  ~candles: array<Config.candlestick>,
): result<LlmEvaluator.setupEvaluation, BotError.t> => {
  let Trade.Symbol(sym) = symbol
  let Trade.Price(price) = currentPrice
  let Trade.Price(baseLevel) = base.priceLevel

  let regimeStr = switch regime {
  | LlmEvaluator.Ranging(_) => "RANGING"
  | LlmEvaluator.TrendingUp(_) => "TRENDING UP"
  | LlmEvaluator.TrendingDown(_) => "TRENDING DOWN"
  | LlmEvaluator.HighVolatility(_) => "HIGH VOLATILITY"
  | LlmEvaluator.Unknown => "UNKNOWN"
  }

  let systemPrompt = "You are a QFL (Quick Fingers Luc) trading setup evaluator. You assess whether a price crack below a support level is a good buying opportunity or should be skipped. Consider: market regime, base strength, crack depth, and whether this looks like a normal dip vs a breakdown. Respond with GO or SKIP followed by your reasoning."

  let candleSummary = LlmEvaluator.summarizeCandles(candles)
  let Config.CrackPercent(crackPct) = crackPercent
  let Config.BounceCount(bounces) = base.bounceCount
  let userPrompt = `Evaluate this QFL setup for ${sym}:

Current price: ${price->Float.toFixed(~digits=2)}
Base level: ${baseLevel->Float.toFixed(~digits=2)} (${bounces->Int.toString} bounces)
Crack: ${crackPct->Float.toFixed(~digits=1)}% below base
Market regime: ${regimeStr}

Recent candle data:
${candleSummary}

Respond: GO or SKIP, then explain why in 1-2 sentences.`

  let result = await callOpenRouter(~member, ~systemPrompt, ~userPrompt)
  result->Result.map(LlmEvaluator.parseEvaluation)
}
