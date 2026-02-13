open Vitest

describe("CcxtMarketData", () => {
  describe("toUnifiedSymbol", () => {
    it("converts BTCUSDT to BTC/USDT", () => {
      let result = CcxtMarketData.toUnifiedSymbol(Trade.Symbol("BTCUSDT"))
      expect(result)->toBe("BTC/USDT")
    })

    it("converts ETHUSDC to ETH/USDC", () => {
      let result = CcxtMarketData.toUnifiedSymbol(Trade.Symbol("ETHUSDC"))
      expect(result)->toBe("ETH/USDC")
    })

    it("converts BTCBUSD to BTC/BUSD", () => {
      let result = CcxtMarketData.toUnifiedSymbol(Trade.Symbol("BTCBUSD"))
      expect(result)->toBe("BTC/BUSD")
    })

    it("converts BTCEUR to BTC/EUR", () => {
      let result = CcxtMarketData.toUnifiedSymbol(Trade.Symbol("BTCEUR"))
      expect(result)->toBe("BTC/EUR")
    })

    it("returns UNKNOWN as-is when no quote currency matches", () => {
      let result = CcxtMarketData.toUnifiedSymbol(Trade.Symbol("UNKNOWN"))
      expect(result)->toBe("UNKNOWN")
    })

    it("converts SOLUSDT to SOL/USDT", () => {
      let result = CcxtMarketData.toUnifiedSymbol(Trade.Symbol("SOLUSDT"))
      expect(result)->toBe("SOL/USDT")
    })
  })

  describe("parseOhlcvRow", () => {
    it("parses valid 6-element row into Some(candlestick)", () => {
      let row = [1000.0, 100.0, 110.0, 90.0, 105.0, 5000.0]
      switch CcxtMarketData.parseOhlcvRow(row) {
      | Some(candle) =>
        let Trade.Timestamp(openTime) = candle.openTime
        expect(openTime)->toBe(1000.0)
        let Trade.Price(open_) = candle.open_
        expect(open_)->toBe(100.0)
        let Trade.Price(high) = candle.high
        expect(high)->toBe(110.0)
        let Trade.Price(low) = candle.low
        expect(low)->toBe(90.0)
        let Trade.Price(close) = candle.close
        expect(close)->toBe(105.0)
        let Config.Volume(volume) = candle.volume
        expect(volume)->toBe(5000.0)
      | None => expect(true)->toBe(false)
      }
    })

    it("returns None for 5-element array (missing volume)", () => {
      let row = [1000.0, 100.0, 110.0, 90.0, 105.0]
      let result = CcxtMarketData.parseOhlcvRow(row)
      expect(result)->toBe(None)
    })

    it("returns None for empty array", () => {
      let row: array<float> = []
      let result = CcxtMarketData.parseOhlcvRow(row)
      expect(result)->toBe(None)
    })
  })
})
