import { describe, it, expect } from "vitest";
import * as LlmEvaluator from "../LlmEvaluator.res.mjs";

describe("LlmEvaluator", () => {
  describe("parseRegime", () => {
    it("detects ranging regime", () => {
      const result = LlmEvaluator.parseRegime("REGIME: RANGING - price is oscillating");
      expect(result.TAG).toBe("Ranging");
      expect(result.confidence).toBe(0.7);
    });

    it("detects trending up from 'trending up'", () => {
      const result = LlmEvaluator.parseRegime("Market is trending up strongly");
      expect(result.TAG).toBe("TrendingUp");
    });

    it("detects trending up from 'bullish'", () => {
      const result = LlmEvaluator.parseRegime("Very bullish sentiment");
      expect(result.TAG).toBe("TrendingUp");
    });

    it("detects trending down from 'trending down'", () => {
      const result = LlmEvaluator.parseRegime("Clearly trending down");
      expect(result.TAG).toBe("TrendingDown");
    });

    it("detects trending down from 'bearish'", () => {
      const result = LlmEvaluator.parseRegime("Market looks bearish");
      expect(result.TAG).toBe("TrendingDown");
    });

    it("detects high volatility", () => {
      const result = LlmEvaluator.parseRegime("Extreme volatility detected");
      expect(result.TAG).toBe("HighVolatility");
    });

    it("detects high volatility from 'volatile'", () => {
      const result = LlmEvaluator.parseRegime("Very volatile market conditions");
      expect(result.TAG).toBe("HighVolatility");
    });

    it("returns Unknown for unrecognized text", () => {
      const result = LlmEvaluator.parseRegime("I have no idea what the market is doing");
      expect(result).toBe("Unknown");
    });
  });

  describe("parseEvaluation", () => {
    it("detects Go signal", () => {
      const result = LlmEvaluator.parseEvaluation("GO - this looks like a good dip buy opportunity");
      expect(result.TAG).toBe("Go");
      expect(result.reasoning).toContain("GO");
    });

    it("detects Skip signal for no-go", () => {
      const result = LlmEvaluator.parseEvaluation("This is a no-go, too risky");
      expect(result.TAG).toBe("Skip");
    });

    it("detects Skip for skip text", () => {
      const result = LlmEvaluator.parseEvaluation("SKIP - this breakdown looks permanent");
      expect(result.TAG).toBe("Skip");
    });

    it("defaults to Skip for ambiguous text", () => {
      const result = LlmEvaluator.parseEvaluation("I'm not sure about this one");
      expect(result.TAG).toBe("Skip");
    });
  });

  describe("summarizeCandles", () => {
    it("formats candles into readable lines", () => {
      const candles = [
        { openTime: 1, open_: 100.5, high: 110.3, low: 95.2, close: 105.8, volume: 1234, closeTime: 2 },
      ];
      const result = LlmEvaluator.summarizeCandles(candles);
      expect(result).toContain("O:100.50");
      expect(result).toContain("H:110.30");
      expect(result).toContain("L:95.20");
      expect(result).toContain("C:105.80");
      expect(result).toContain("V:1234");
    });

    it("joins multiple candles with newlines", () => {
      const candles = [
        { openTime: 1, open_: 100, high: 110, low: 90, close: 105, volume: 1000, closeTime: 2 },
        { openTime: 2, open_: 105, high: 115, low: 95, close: 110, volume: 2000, closeTime: 3 },
      ];
      const result = LlmEvaluator.summarizeCandles(candles);
      const lines = result.split("\n");
      expect(lines.length).toBe(2);
    });

    it("returns empty string for empty candles", () => {
      expect(LlmEvaluator.summarizeCandles([])).toBe("");
    });
  });

  describe("regimeToString", () => {
    it("formats Ranging", () => {
      const result = LlmEvaluator.regimeToString({ TAG: "Ranging", confidence: 0.7 });
      expect(result).toBe("Ranging (0.7)");
    });

    it("formats TrendingUp", () => {
      const result = LlmEvaluator.regimeToString({ TAG: "TrendingUp", confidence: 0.8 });
      expect(result).toBe("Trending Up (0.8)");
    });

    it("formats TrendingDown", () => {
      const result = LlmEvaluator.regimeToString({ TAG: "TrendingDown", confidence: 0.6 });
      expect(result).toBe("Trending Down (0.6)");
    });

    it("formats HighVolatility", () => {
      const result = LlmEvaluator.regimeToString({ TAG: "HighVolatility", confidence: 0.9 });
      expect(result).toBe("High Volatility (0.9)");
    });

    it("formats Unknown", () => {
      const result = LlmEvaluator.regimeToString("Unknown");
      expect(result).toBe("Unknown");
    });
  });

  describe("extractResponseText", () => {
    it("extracts text from Claude API response shape", () => {
      const response = {
        content: [{ type: "text", text: "This is the response" }],
      };
      const result = LlmEvaluator.extractResponseText(response);
      expect(result).toBe("This is the response");
    });

    it("returns undefined for invalid response", () => {
      expect(LlmEvaluator.extractResponseText({})).toBeUndefined();
      expect(LlmEvaluator.extractResponseText(null)).toBeUndefined();
      expect(LlmEvaluator.extractResponseText("string")).toBeUndefined();
    });

    it("returns undefined for empty content array", () => {
      const result = LlmEvaluator.extractResponseText({ content: [] });
      expect(result).toBeUndefined();
    });
  });

  describe("buildRequestBody", () => {
    it("builds correct Claude API request shape", () => {
      const body = LlmEvaluator.buildRequestBody("claude-sonnet-4-5-20250929", "You are helpful", "What is 2+2?");
      expect(body.model).toBe("claude-sonnet-4-5-20250929");
      expect(body.max_tokens).toBe(500);
      expect(body.system).toBe("You are helpful");
      expect(body.messages.length).toBe(1);
      expect(body.messages[0].role).toBe("user");
      expect(body.messages[0].content).toBe("What is 2+2?");
    });
  });
});
