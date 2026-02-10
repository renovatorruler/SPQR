import { describe, it, expect } from "vitest";
import * as PaperExchange from "../PaperExchange.res.mjs";

function makeExchange() {
  const result = PaperExchange.make({ exchangeId: "PaperExchange" });
  return result._0; // unwrap Ok
}

describe("PaperExchange", () => {
  describe("make", () => {
    it("creates exchange with 10000 starting balance", () => {
      const exchange = makeExchange();
      expect(exchange.state.balance).toBe(10000.0);
      expect(exchange.state.trades.length).toBe(0);
    });
  });

  describe("getBalance", () => {
    it("returns current balance", async () => {
      const exchange = makeExchange();
      const result = await PaperExchange.getBalance(exchange);
      expect(result.TAG).toBe("Ok");
      expect(result._0).toBe(10000.0);
    });
  });

  describe("setCurrentPrice / getMarketPrice", () => {
    it("stores and retrieves market price", () => {
      const exchange = makeExchange();
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 50000.0);
      const result = PaperExchange.getMarketPrice(exchange, "BTCUSDT", "Market");
      expect(result.TAG).toBe("Ok");
      expect(result._0).toBe(50000.0);
    });

    it("returns error when no price set", () => {
      const exchange = makeExchange();
      const result = PaperExchange.getMarketPrice(exchange, "UNKNOWN", "Market");
      expect(result.TAG).toBe("Error");
    });

    it("uses limit price when order type is Limit", () => {
      const exchange = makeExchange();
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 50000.0);
      const result = PaperExchange.getMarketPrice(exchange, "BTCUSDT", { TAG: "Limit", limitPrice: 49000.0 });
      expect(result.TAG).toBe("Ok");
      expect(result._0).toBe(49000.0);
    });
  });

  describe("placeOrder", () => {
    it("executes a buy order and deducts balance", async () => {
      const exchange = makeExchange();
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 100.0);
      const result = await PaperExchange.placeOrder(exchange, "BTCUSDT", "Buy", "Market", 10.0);
      expect(result.TAG).toBe("Ok");
      expect(result._0.status.TAG).toBe("Filled");
      expect(result._0.status.filledPrice).toBe(100.0);
      expect(exchange.state.balance).toBe(9000.0); // 10000 - 100*10
    });

    it("executes a sell order and adds to balance", async () => {
      const exchange = makeExchange();
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 100.0);
      const result = await PaperExchange.placeOrder(exchange, "BTCUSDT", "Sell", "Market", 5.0);
      expect(result.TAG).toBe("Ok");
      expect(exchange.state.balance).toBe(10500.0); // 10000 + 100*5
    });

    it("rejects buy when insufficient balance", async () => {
      const exchange = makeExchange();
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 50000.0);
      const result = await PaperExchange.placeOrder(exchange, "BTCUSDT", "Buy", "Market", 1.0);
      expect(result.TAG).toBe("Error");
      expect(result._0._0.TAG).toBe("InsufficientBalance");
    });

    it("generates unique trade IDs", async () => {
      const exchange = makeExchange();
      PaperExchange.setCurrentPrice(exchange, "BTCUSDT", 10.0);
      const r1 = await PaperExchange.placeOrder(exchange, "BTCUSDT", "Buy", "Market", 1.0);
      const r2 = await PaperExchange.placeOrder(exchange, "BTCUSDT", "Buy", "Market", 1.0);
      expect(r1._0.id).not.toBe(r2._0.id);
    });

    it("records trades in state", async () => {
      const exchange = makeExchange();
      PaperExchange.setCurrentPrice(exchange, "ETHUSDT", 50.0);
      await PaperExchange.placeOrder(exchange, "ETHUSDT", "Buy", "Market", 2.0);
      expect(exchange.state.trades.length).toBe(1);
      expect(exchange.state.trades[0].symbol).toBe("ETHUSDT");
    });
  });

  describe("trimTrades", () => {
    it("trims trades when exceeding 1000", () => {
      const exchange = makeExchange();
      // Manually push 1001 trades
      for (let i = 0; i < 1001; i++) {
        exchange.state.trades.push({ id: `trade-${i}` });
      }
      PaperExchange.trimTrades(exchange);
      expect(exchange.state.trades.length).toBe(1000);
    });
  });
});
