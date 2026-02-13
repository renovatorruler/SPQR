// OpenRouter Evaluator — backward-compatibility facade
//
// Delegates to OpenRouterApi via LlmService. Existing call sites continue to work.
// New code should use LlmService directly.

// Re-export fetch types for test compatibility
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

let buildRequestBody = OpenRouterApi.buildRequestBody
let extractResponseText = OpenRouterApi.extractResponseText

let callOpenRouter = async (
  ~member: Config.llmMember,
  ~systemPrompt: string,
  ~userPrompt: string,
): result<string, BotError.t> => {
  let config = LlmShared.configFromMember(member)
  await OpenRouterApi.callApi(~config, ~systemPrompt, ~userPrompt)
}

let evaluateSetup = async (
  ~member: Config.llmMember,
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: LlmShared.marketRegime,
  ~candles: array<Config.candlestick>,
): result<LlmShared.setupEvaluation, BotError.t> => {
  let config = LlmShared.configFromMember(member)
  await LlmService.OpenRouter.evaluateSetup(
    ~symbol,
    ~base,
    ~currentPrice,
    ~crackPercent,
    ~regime,
    ~candles,
    ~config,
  )
}
