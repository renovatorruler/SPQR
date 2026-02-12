open Vitest

describe("LlmEvaluator", () => {
  describe("parseRegime", () => {
    it("detects ranging regime", () => {
      switch LlmEvaluator.parseRegime("REGIME: RANGING - price is oscillating") {
      | Ranging({confidence: Config.Confidence(c)}) => expect(c)->toBe(0.7)
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects trending up from 'trending up'", () => {
      switch LlmEvaluator.parseRegime("Market is trending up strongly") {
      | TrendingUp(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects trending up from 'bullish'", () => {
      switch LlmEvaluator.parseRegime("Very bullish sentiment") {
      | TrendingUp(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects trending down from 'trending down'", () => {
      switch LlmEvaluator.parseRegime("Clearly trending down") {
      | TrendingDown(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects trending down from 'bearish'", () => {
      switch LlmEvaluator.parseRegime("Market looks bearish") {
      | TrendingDown(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects high volatility", () => {
      switch LlmEvaluator.parseRegime("Extreme volatility detected") {
      | HighVolatility(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects high volatility from 'volatile'", () => {
      switch LlmEvaluator.parseRegime("Very volatile market conditions") {
      | HighVolatility(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("returns Unknown for unrecognized text", () => {
      switch LlmEvaluator.parseRegime("I have no idea what the market is doing") {
      | Unknown => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })
  })

  describe("parseEvaluation", () => {
    it("detects Go signal", () => {
      switch LlmEvaluator.parseEvaluation("GO - this looks like a good dip buy opportunity") {
      | Go({reasoning}) =>
        expect(reasoning)->toContainString("GO")
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects Skip signal for no-go", () => {
      switch LlmEvaluator.parseEvaluation("This is a no-go, too risky") {
      | Skip(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("detects Skip for skip text", () => {
      switch LlmEvaluator.parseEvaluation("SKIP - this breakdown looks permanent") {
      | Skip(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    it("defaults to Skip for ambiguous text", () => {
      switch LlmEvaluator.parseEvaluation("I'm not sure about this one") {
      | Skip(_) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })
  })

  describe("summarizeCandles", () => {
    it("formats candles into readable lines", () => {
      let candles: array<Config.candlestick> = [
        {
          openTime: Trade.Timestamp(1.0),
          open_: Trade.Price(100.5),
          high: Trade.Price(110.3),
          low: Trade.Price(95.2),
          close: Trade.Price(105.8),
          volume: Config.Volume(1234.0),
          closeTime: Trade.Timestamp(2.0),
        },
      ]
      let result = LlmEvaluator.summarizeCandles(candles)
      expect(result)->toContainString("O:100.50")
      expect(result)->toContainString("H:110.30")
      expect(result)->toContainString("L:95.20")
      expect(result)->toContainString("C:105.80")
      expect(result)->toContainString("V:1234")
    })

    it("joins multiple candles with newlines", () => {
      let candles: array<Config.candlestick> = [
        {
          openTime: Trade.Timestamp(1.0),
          open_: Trade.Price(100.0),
          high: Trade.Price(110.0),
          low: Trade.Price(90.0),
          close: Trade.Price(105.0),
          volume: Config.Volume(1000.0),
          closeTime: Trade.Timestamp(2.0),
        },
        {
          openTime: Trade.Timestamp(2.0),
          open_: Trade.Price(105.0),
          high: Trade.Price(115.0),
          low: Trade.Price(95.0),
          close: Trade.Price(110.0),
          volume: Config.Volume(2000.0),
          closeTime: Trade.Timestamp(3.0),
        },
      ]
      let result = LlmEvaluator.summarizeCandles(candles)
      let lines = result->String.split("\n")
      expect(lines)->toHaveLength(2)
    })

    it("returns empty string for empty candles", () => {
      expect(LlmEvaluator.summarizeCandles([]))->toBe("")
    })
  })

  describe("regimeToString", () => {
    it("formats Ranging", () => {
      let result = LlmEvaluator.regimeToString(Ranging({confidence: Config.Confidence(0.7)}))
      expect(result)->toBe("Ranging (0.7)")
    })

    it("formats TrendingUp", () => {
      let result = LlmEvaluator.regimeToString(TrendingUp({confidence: Config.Confidence(0.8)}))
      expect(result)->toBe("Trending Up (0.8)")
    })

    it("formats TrendingDown", () => {
      let result = LlmEvaluator.regimeToString(
        TrendingDown({confidence: Config.Confidence(0.6)}),
      )
      expect(result)->toBe("Trending Down (0.6)")
    })

    it("formats HighVolatility", () => {
      let result = LlmEvaluator.regimeToString(
        HighVolatility({confidence: Config.Confidence(0.9)}),
      )
      expect(result)->toBe("High Volatility (0.9)")
    })

    it("formats Unknown", () => {
      let result = LlmEvaluator.regimeToString(Unknown)
      expect(result)->toBe("Unknown")
    })
  })

  describe("extractResponseText", () => {
    it("extracts text from Claude API response shape", () => {
      let response =
        Dict.fromArray([
          (
            "content",
            [
              Dict.fromArray([
                ("type", "text"->JSON.Encode.string),
                ("text", "This is the response"->JSON.Encode.string),
              ])->JSON.Encode.object,
            ]->JSON.Encode.array,
          ),
        ])->JSON.Encode.object
      switch LlmEvaluator.extractResponseText(response) {
      | Some(text) => expect(text)->toBe("This is the response")
      | None => expect(true)->toBe(false)
      }
    })

    it("returns None for empty object", () => {
      switch LlmEvaluator.extractResponseText(Dict.make()->JSON.Encode.object) {
      | Some(_) => expect(true)->toBe(false)
      | None => expect(true)->toBe(true)
      }
    })

    it("returns None for null", () => {
      switch LlmEvaluator.extractResponseText(JSON.Encode.null) {
      | Some(_) => expect(true)->toBe(false)
      | None => expect(true)->toBe(true)
      }
    })

    it("returns None for string", () => {
      switch LlmEvaluator.extractResponseText("string"->JSON.Encode.string) {
      | Some(_) => expect(true)->toBe(false)
      | None => expect(true)->toBe(true)
      }
    })

    it("returns None for empty content array", () => {
      let response =
        Dict.fromArray([("content", []->JSON.Encode.array)])->JSON.Encode.object
      switch LlmEvaluator.extractResponseText(response) {
      | Some(_) => expect(true)->toBe(false)
      | None => expect(true)->toBe(true)
      }
    })
  })

  describe("buildRequestBody", () => {
    it("builds correct Claude API request shape", () => {
      let body = LlmEvaluator.buildRequestBody(
        ~model=Config.LlmModel("claude-sonnet-4-5-20250929"),
        ~systemPrompt="You are helpful",
        ~userPrompt="What is 2+2?",
      )
      let obj = body->JSON.Decode.object->Option.getOrThrow
      let model = obj->Dict.get("model")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
      expect(model)->toBe("claude-sonnet-4-5-20250929")

      let maxTokens =
        obj->Dict.get("max_tokens")->Option.flatMap(JSON.Decode.float)->Option.getOrThrow
      expect(maxTokens)->toBe(500.0)

      let system = obj->Dict.get("system")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
      expect(system)->toBe("You are helpful")

      let messages =
        obj->Dict.get("messages")->Option.flatMap(JSON.Decode.array)->Option.getOrThrow
      expect(messages)->toHaveLength(1)

      let msg0 = messages[0]->Option.flatMap(JSON.Decode.object)->Option.getOrThrow
      let role = msg0->Dict.get("role")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
      expect(role)->toBe("user")

      let content =
        msg0->Dict.get("content")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
      expect(content)->toBe("What is 2+2?")
    })
  })
})
