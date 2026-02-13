// LLM Evaluator — backward-compatibility facade
//
// Re-exports types and utilities from LlmShared, delegates API calls to
// AnthropicApi via LlmService. Existing call sites and tests continue to work.
// New code should use LlmShared (types) and LlmService (operations) directly.

// -- Re-exported types --

let defaultConfidence = LlmShared.defaultConfidence

type marketRegime = LlmShared.marketRegime =
  | Ranging({confidence: Config.confidence})
  | TrendingUp({confidence: Config.confidence})
  | TrendingDown({confidence: Config.confidence})
  | HighVolatility({confidence: Config.confidence})
  | Unknown

type setupEvaluation = LlmShared.setupEvaluation =
  | Go({reasoning: string})
  | Skip({reasoning: string})

// -- Re-exported utilities --

let summarizeCandles = LlmShared.summarizeCandles
let parseRegime = LlmShared.parseRegime
let parseEvaluation = LlmShared.parseEvaluation
let regimeToString = LlmShared.regimeToString

// -- Anthropic-specific internals (kept for test compatibility) --

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

// Build request body for Claude API (kept for test compatibility)
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

// Extract text content from Claude API response (kept for test compatibility)
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

// Call Claude API — delegates to AnthropicApi
let callClaude = async (
  ~config: Config.llmConfig,
  ~systemPrompt: string,
  ~userPrompt: string,
): result<string, BotError.t> => {
  let providerConfig = LlmShared.configFromLlmConfig(config)
  await AnthropicApi.callApi(~config=providerConfig, ~systemPrompt, ~userPrompt)
}

// Assess market regime — delegates to LlmService.Anthropic
let assessRegime = async (
  ~candles: array<Config.candlestick>,
  ~config: Config.llmConfig,
): result<marketRegime, BotError.t> => {
  let providerConfig = LlmShared.configFromLlmConfig(config)
  await LlmService.Anthropic.assessRegime(~candles, ~config=providerConfig)
}

// Evaluate setup — delegates to LlmService.Anthropic
let evaluateSetup = async (
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: marketRegime,
  ~candles: array<Config.candlestick>,
  ~config: Config.llmConfig,
): result<setupEvaluation, BotError.t> => {
  let providerConfig = LlmShared.configFromLlmConfig(config)
  await LlmService.Anthropic.evaluateSetup(
    ~symbol,
    ~base,
    ~currentPrice,
    ~crackPercent,
    ~regime,
    ~candles,
    ~config=providerConfig,
  )
}
