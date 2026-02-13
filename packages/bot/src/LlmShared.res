// LLM shared types, prompts, and parsing utilities
//
// Extracted from LlmEvaluator.res and OpenRouterEvaluator.res to eliminate
// duplication. All provider-agnostic logic lives here.

// -- Shared types --

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

// Unified provider config — normalizes Anthropic's llmConfig and OpenRouter's llmMember
type providerConfig = {
  apiKey: Config.llmApiKey,
  modelId: string,
  baseUrl: string,
  timeout: Config.timeoutMs,
}

// Construct a providerConfig from an llmMember (committee context)
let configFromMember = (member: Config.llmMember): providerConfig => {
  let Config.LlmModelId(modelId) = member.modelId
  let Config.LlmApiKey(_) as apiKey = member.apiKey
  let Config.LlmBaseUrl(baseUrl) = member.apiBase
  {
    apiKey,
    modelId,
    baseUrl,
    timeout: member.timeout,
  }
}

// Construct a providerConfig from an llmConfig (standalone Anthropic context)
let configFromLlmConfig = (config: Config.llmConfig): providerConfig => {
  let Config.LlmModel(modelId) = config.model
  {
    apiKey: config.apiKey,
    modelId,
    baseUrl: "https://api.anthropic.com/v1/messages",
    timeout: Config.TimeoutMs(30000),
  }
}

// -- Candle summarization --

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

// -- Response parsing --

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

let parseEvaluation = (text: string): setupEvaluation => {
  let lower = text->String.toLowerCase
  switch lower->String.includes("go") && !(lower->String.includes("no-go")) {
  | true => Go({reasoning: text})
  | false => Skip({reasoning: text})
  }
}

// -- Regime string conversion --

let regimeToString = (regime: marketRegime): string => {
  switch regime {
  | Ranging({confidence: Config.Confidence(c)}) => `Ranging (${c->Float.toFixed(~digits=1)})`
  | TrendingUp({confidence: Config.Confidence(c)}) => `Trending Up (${c->Float.toFixed(~digits=1)})`
  | TrendingDown({confidence: Config.Confidence(c)}) =>
    `Trending Down (${c->Float.toFixed(~digits=1)})`
  | HighVolatility({confidence: Config.Confidence(c)}) =>
    `High Volatility (${c->Float.toFixed(~digits=1)})`
  | Unknown => "Unknown"
  }
}

let regimeToLabel = (regime: marketRegime): string => {
  switch regime {
  | Ranging(_) => "RANGING"
  | TrendingUp(_) => "TRENDING UP"
  | TrendingDown(_) => "TRENDING DOWN"
  | HighVolatility(_) => "HIGH VOLATILITY"
  | Unknown => "UNKNOWN"
  }
}

// -- Prompt builders --

let regimeSystemPrompt = "You are a market regime classifier. Analyze the provided candlestick data and classify the current market regime as one of: RANGING, TRENDING UP, TRENDING DOWN, or HIGH VOLATILITY. Respond with the regime type and a brief explanation. Be concise."

let setupSystemPrompt = "You are a QFL (Quick Fingers Luc) trading setup evaluator. You assess whether a price crack below a support level is a good buying opportunity or should be skipped. Consider: market regime, base strength, crack depth, and whether this looks like a normal dip vs a breakdown. Respond with GO or SKIP followed by your reasoning."

let buildRegimeUserPrompt = (~candles: array<Config.candlestick>): string => {
  let candleSummary = summarizeCandles(candles)
  `Classify the market regime from this recent candle data (oldest to newest):

${candleSummary}

Respond with: REGIME: [type]
Explanation: [1-2 sentences]`
}

let buildSetupUserPrompt = (
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: marketRegime,
  ~candles: array<Config.candlestick>,
): string => {
  let Trade.Symbol(sym) = symbol
  let Trade.Price(price) = currentPrice
  let Trade.Price(baseLevel) = base.priceLevel
  let Config.CrackPercent(crackPct) = crackPercent
  let Config.BounceCount(bounces) = base.bounceCount
  let candleSummary = summarizeCandles(candles)
  let regimeStr = regimeToLabel(regime)

  `Evaluate this QFL setup for ${sym}:

Current price: ${price->Float.toFixed(~digits=2)}
Base level: ${baseLevel->Float.toFixed(~digits=2)} (${bounces->Int.toString} bounces)
Crack: ${crackPct->Float.toFixed(~digits=1)}% below base
Market regime: ${regimeStr}

Recent candle data:
${candleSummary}

Respond: GO or SKIP, then explain why in 1-2 sentences.`
}
