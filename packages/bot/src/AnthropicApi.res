// Anthropic API provider — Claude messages endpoint
//
// Implements LlmProvider.S for the Anthropic-specific protocol:
// - x-api-key header (not Bearer token)
// - anthropic-version header
// - system prompt as top-level field (not a message role)
// - response shape: { content: [{ text: "..." }] }

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

let buildRequestBody = (~modelId: string, ~systemPrompt: string, ~userPrompt: string): JSON.t => {
  let messages = [
    Dict.fromArray([
      ("role", "user"->JSON.Encode.string),
      ("content", userPrompt->JSON.Encode.string),
    ])->JSON.Encode.object,
  ]

  Dict.fromArray([
    ("model", modelId->JSON.Encode.string),
    ("max_tokens", 500.0->JSON.Encode.float),
    ("system", systemPrompt->JSON.Encode.string),
    ("messages", messages->JSON.Encode.array),
  ])->JSON.Encode.object
}

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

let callApi = async (
  ~config: LlmShared.providerConfig,
  ~systemPrompt: string,
  ~userPrompt: string,
): result<string, BotError.t> => {
  let Config.LlmApiKey(apiKey) = config.apiKey
  let body = buildRequestBody(~modelId=config.modelId, ~systemPrompt, ~userPrompt)

  try {
    let response = await LlmProvider.fetch(
      config.baseUrl,
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

    if !LlmProvider.ok(response) {
      Error(BotError.LlmError(ApiCallFailed({message: LlmProvider.statusText(response)})))
    } else {
      let jsonData = await LlmProvider.json(response)
      switch extractResponseText(jsonData) {
      | Some(text) => Ok(text)
      | None =>
        Error(
          BotError.LlmError(
            InvalidLlmResponse({message: "Could not extract text from Anthropic response"}),
          ),
        )
      }
    }
  } catch {
  | JsExn(jsExn) =>
    let msg = jsExn->JsExn.message->Option.getOr("Unknown error")
    Error(BotError.LlmError(ApiCallFailed({message: msg})))
  | _ => Error(BotError.LlmError(ApiCallFailed({message: "Unknown error"})))
  }
}
