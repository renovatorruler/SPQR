// OpenRouter API provider — OpenAI-compatible chat completions
//
// Implements LlmProvider.S for the OpenRouter protocol:
// - Bearer token auth
// - HTTP-Referer + X-Title headers (OpenRouter requirements)
// - system prompt as a message role
// - response shape: { choices: [{ message: { content: "..." } }] }

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

let buildRequestBody = (~modelId: string, ~systemPrompt: string, ~userPrompt: string): JSON.t => {
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
    ("model", modelId->JSON.Encode.string),
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

let callApi = async (
  ~config: LlmShared.providerConfig,
  ~systemPrompt: string,
  ~userPrompt: string,
): result<string, BotError.t> => {
  let Config.LlmApiKey(apiKey) = config.apiKey
  let body = buildRequestBody(~modelId=config.modelId, ~systemPrompt, ~userPrompt)

  try {
    let response = await LlmProvider.fetch(
      `${config.baseUrl}/chat/completions`,
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

    if !LlmProvider.ok(response) {
      Error(BotError.LlmError(ApiCallFailed({message: LlmProvider.statusText(response)})))
    } else {
      let jsonData = await LlmProvider.json(response)
      switch extractResponseText(jsonData) {
      | Some(text) => Ok(text)
      | None =>
        Error(
          BotError.LlmError(
            InvalidLlmResponse({message: "Could not extract text from OpenRouter response"}),
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
