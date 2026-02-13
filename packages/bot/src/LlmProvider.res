// LLM Provider — module type interface for LLM API backends
//
// Each provider implements a single `callApi` function that handles the
// provider-specific HTTP protocol (headers, body format, response parsing).
// Higher-level operations (assessRegime, evaluateSetup) are built on top
// via LlmService, eliminating duplication across providers.

module type S = {
  // The only function a provider must implement — send a prompt pair and get text back.
  // All protocol differences (auth headers, body shape, response extraction) live here.
  let callApi: (
    ~config: LlmShared.providerConfig,
    ~systemPrompt: string,
    ~userPrompt: string,
  ) => promise<result<string, BotError.t>>
}

// -- Fetch bindings (shared by both providers) --

@val external fetch: (string, 'options) => promise<'response> = "fetch"
@send external json: 'response => promise<JSON.t> = "json"
@get external ok: 'response => bool = "ok"
@get external statusText: 'response => string = "statusText"
