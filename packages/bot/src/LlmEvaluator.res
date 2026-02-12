// LLM Evaluator — uses Claude API for market regime analysis and setup evaluation
//
// Two modes:
// 1. assessRegime: periodic market mood check (ranging/trending/volatile)
// 2. evaluateSetup: per-crack go/no-go decision with reasoning

let defaultConfidence = Config.Confidence(0.7)

type marketRegime =
  | Ranging({confidence: Config.confidence})
  | TrendingUp({confidence: Config.confidence})
  | TrendingDown({confidence: Config.confidence})
  | HighVolatility({confidence: Config.confidence})
  | Unknown

type setupEvaluation =
  | Go({reasoning: string})
  | Skip({reasoning: string})

// Claude API bindings
type fetchHeaders = {
  @as("Content-Type") contentType: string,
  @as("x-api-key") xApiKey: string,
  @as("anthropic-version") anthropicVersion: string,
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

// Summarize candles into a compact text format for the LLM
let summarizeCandles = (candles: array<Config.candlestick>): string => {
  let lines = candles->Array.map(c => {
    let Trade.Price(o) = c.open_
    let Trade.Price(h) = c.high
    let Trade.Price(l) = c.low
    let Trade.Price(cl) = c.close
    let Config.Volume(v) = c.volume
    `O:${o->Float.toFixed(~digits=2)} H:${h->Float.toFixed(~digits=2)} L:${l->Float.toFixed(~digits=2)} C:${cl->Float.toFixed(~digits=2)} V:${v->Float.toFixed(~digits=0)}`
  })
  lines->Array.join("\n")
}

// Build request body for Claude API
let buildRequestBody = (
  ~model: Config.llmModel,
  ~systemPrompt: string,
  ~userPrompt: string,
): JSON.t => {
  let Config.LlmModel(modelStr) = model
  let messages = [
    Dict.fromArray([
      ("role", "user"->JSON.Encode.string),
      ("content", userPrompt->JSON.Encode.string),
    ])->JSON.Encode.object,
  ]

  Dict.fromArray([
    ("model", modelStr->JSON.Encode.string),
    ("max_tokens", 500.0->JSON.Encode.float),
    ("system", systemPrompt->JSON.Encode.string),
    ("messages", messages->JSON.Encode.array),
  ])->JSON.Encode.object
}

// Extract text content from Claude API response
let extractResponseText = (json: JSON.t): option<string> => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get("content"))
  ->Option.flatMap(JSON.Decode.array)
  ->Option.flatMap(arr => arr[0])
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(obj => obj->Dict.get("text"))
  ->Option.flatMap(JSON.Decode.string)
}

// Call Claude API
let callClaude = async (
  ~config: Config.llmConfig,
  ~systemPrompt: string,
  ~userPrompt: string,
): result<string, BotError.t> => {
  let Config.LlmApiKey(apiKey) = config.apiKey
  let body = buildRequestBody(~model=config.model, ~systemPrompt, ~userPrompt)

  try {
    let response = await fetch(
      "https://api.anthropic.com/v1/messages",
      {
        method: "POST",
        headers: {
          contentType: "application/json",
          xApiKey: apiKey,
          anthropicVersion: "2023-06-01",
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
      | None =>
        Error(BotError.LlmError(InvalidLlmResponse({message: "Could not extract text from response"})))
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

// Parse regime response from LLM
let parseRegime = (text: string): marketRegime => {
  let lower = text->String.toLowerCase
  switch true {
  | _ if lower->String.includes("ranging") => Ranging({confidence: defaultConfidence})
  | _ if lower->String.includes("trending up") || lower->String.includes("bullish") =>
    TrendingUp({confidence: defaultConfidence})
  | _ if lower->String.includes("trending down") || lower->String.includes("bearish") =>
    TrendingDown({confidence: defaultConfidence})
  | _ if lower->String.includes("volatile") || lower->String.includes("volatility") =>
    HighVolatility({confidence: defaultConfidence})
  | _ => Unknown
  }
}

// Parse setup evaluation response from LLM
let parseEvaluation = (text: string): setupEvaluation => {
  let lower = text->String.toLowerCase
  switch lower->String.includes("go") && !(lower->String.includes("no-go")) {
  | true => Go({reasoning: text})
  | false => Skip({reasoning: text})
  }
}

let assessRegime = async (
  ~candles: array<Config.candlestick>,
  ~config: Config.llmConfig,
): result<marketRegime, BotError.t> => {
  let systemPrompt = "You are a market regime classifier. Analyze the provided candlestick data and classify the current market regime as one of: RANGING, TRENDING UP, TRENDING DOWN, or HIGH VOLATILITY. Respond with the regime type and a brief explanation. Be concise."

  let candleSummary = summarizeCandles(candles)
  let userPrompt = `Classify the market regime from this recent candle data (oldest to newest):

${candleSummary}

Respond with: REGIME: [type]
Explanation: [1-2 sentences]`

  let result = await callClaude(~config, ~systemPrompt, ~userPrompt)
  result->Result.map(parseRegime)
}

let evaluateSetup = async (
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: marketRegime,
  ~candles: array<Config.candlestick>,
  ~config: Config.llmConfig,
): result<setupEvaluation, BotError.t> => {
  let Trade.Symbol(sym) = symbol
  let Trade.Price(price) = currentPrice
  let Trade.Price(baseLevel) = base.priceLevel

  let regimeStr = switch regime {
  | Ranging(_) => "RANGING"
  | TrendingUp(_) => "TRENDING UP"
  | TrendingDown(_) => "TRENDING DOWN"
  | HighVolatility(_) => "HIGH VOLATILITY"
  | Unknown => "UNKNOWN"
  }

  let systemPrompt = "You are a QFL (Quick Fingers Luc) trading setup evaluator. You assess whether a price crack below a support level is a good buying opportunity or should be skipped. Consider: market regime, base strength, crack depth, and whether this looks like a normal dip vs a breakdown. Respond with GO or SKIP followed by your reasoning."

  let candleSummary = summarizeCandles(candles)
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

  let result = await callClaude(~config, ~systemPrompt, ~userPrompt)
  result->Result.map(parseEvaluation)
}

let regimeToString = (regime: marketRegime): string => {
  switch regime {
  | Ranging({confidence: Config.Confidence(c)}) => `Ranging (${c->Float.toFixed(~digits=1)})`
  | TrendingUp({confidence: Config.Confidence(c)}) => `Trending Up (${c->Float.toFixed(~digits=1)})`
  | TrendingDown({confidence: Config.Confidence(c)}) => `Trending Down (${c->Float.toFixed(~digits=1)})`
  | HighVolatility({confidence: Config.Confidence(c)}) => `High Volatility (${c->Float.toFixed(~digits=1)})`
  | Unknown => "Unknown"
  }
}
