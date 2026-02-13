// LLM Service — generic assessRegime + evaluateSetup built on any LlmProvider
//
// The Make functor takes a provider's `callApi` and constructs the two
// high-level operations the bot needs. Prompts and parsing come from LlmShared.
// The provider only handles the HTTP protocol differences.

// Build assessRegime and evaluateSetup for a given provider's callApi
module Make = (Provider: LlmProvider.S) => {
  let assessRegime = async (
    ~candles: array<Config.candlestick>,
    ~config: LlmShared.providerConfig,
  ): result<LlmShared.marketRegime, BotError.t> => {
    let userPrompt = LlmShared.buildRegimeUserPrompt(~candles)
    let result = await Provider.callApi(
      ~config,
      ~systemPrompt=LlmShared.regimeSystemPrompt,
      ~userPrompt,
    )
    result->Result.map(LlmShared.parseRegime)
  }

  let evaluateSetup = async (
    ~symbol: Trade.symbol,
    ~base: BaseDetector.base,
    ~currentPrice: Trade.price,
    ~crackPercent: Config.crackPercent,
    ~regime: LlmShared.marketRegime,
    ~candles: array<Config.candlestick>,
    ~config: LlmShared.providerConfig,
  ): result<LlmShared.setupEvaluation, BotError.t> => {
    let userPrompt = LlmShared.buildSetupUserPrompt(
      ~symbol,
      ~base,
      ~currentPrice,
      ~crackPercent,
      ~regime,
      ~candles,
    )
    let result = await Provider.callApi(
      ~config,
      ~systemPrompt=LlmShared.setupSystemPrompt,
      ~userPrompt,
    )
    result->Result.map(LlmShared.parseEvaluation)
  }
}

// Pre-instantiated services for each supported provider
module Anthropic = Make(AnthropicApi)
module OpenRouter = Make(OpenRouterApi)

// Dispatch evaluateSetup to the correct pre-instantiated provider service
let evaluateSetup = async (
  ~provider: Config.llmProvider,
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: LlmShared.marketRegime,
  ~candles: array<Config.candlestick>,
  ~config: LlmShared.providerConfig,
): result<LlmShared.setupEvaluation, BotError.t> => {
  switch provider {
  | Config.Anthropic =>
    await Anthropic.evaluateSetup(
      ~symbol,
      ~base,
      ~currentPrice,
      ~crackPercent,
      ~regime,
      ~candles,
      ~config,
    )
  | Config.OpenRouter
  | Config.OpenAI
  | Config.Google
  | Config.Mistral
  | Config.Cohere
  | Config.Local =>
    await OpenRouter.evaluateSetup(
      ~symbol,
      ~base,
      ~currentPrice,
      ~crackPercent,
      ~regime,
      ~candles,
      ~config,
    )
  }
}

// Dispatch assessRegime to the correct pre-instantiated provider service
let assessRegime = async (
  ~provider: Config.llmProvider,
  ~candles: array<Config.candlestick>,
  ~config: LlmShared.providerConfig,
): result<LlmShared.marketRegime, BotError.t> => {
  switch provider {
  | Config.Anthropic => await Anthropic.assessRegime(~candles, ~config)
  | Config.OpenRouter
  | Config.OpenAI
  | Config.Google
  | Config.Mistral
  | Config.Cohere
  | Config.Local =>
    await OpenRouter.assessRegime(~candles, ~config)
  }
}
