import { describe, it, expect } from "vitest";
import * as BotConfig from "../BotConfig.res.mjs";

describe("BotConfig", () => {
  it("loads typed config", () => {
    const result = BotConfig.load();
    expect(result.TAG).toBe("Ok");
    const cfg = result._0;
    expect(cfg.tradingMode).toBe("Paper");
    expect(cfg.exchange.exchangeId).toBe("Kraken");
    expect(cfg.symbols.length).toBeGreaterThan(0);
    expect(cfg.qfl.crackThreshold).toBeDefined();
    expect(cfg.qfl.setupEvaluation.TAG).toBe("Committee");
  });
});
