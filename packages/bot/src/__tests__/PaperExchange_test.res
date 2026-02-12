open Vitest

let makeExchange = () => {
  switch PaperExchange.make({
    exchangeId: Config.PaperExchange,
    baseUrl: None,
    apiKey: None,
    apiSecret: None,
  }) {
  | Ok(ex) => ex
  | Error(_) => panic("makeExchange failed")
  }
}

describe("PaperExchange", () => {
  describe("make", () => {
    it("creates exchange with 10000 starting balance", () => {
      let exchange = makeExchange()
      let Config.Balance(bal) = exchange.state.balance
      expect(bal)->toBe(10000.0)
      expect(exchange.state.trades->Array.length)->toBe(0)
    })
  })

  describe("getBalance", () => {
    itAsync("returns current balance", async () => {
      let exchange = makeExchange()
      let result = await PaperExchange.getBalance(exchange)
      switch result {
      | Ok(Config.Balance(bal)) => expect(bal)->toBe(10000.0)
      | Error(_) => expect(true)->toBe(false)
      }
    })
  })

  describe("setCurrentPrice / getMarketPrice", () => {
    it("stores and retrieves market price", () => {
      let exchange = makeExchange()
      PaperExchange.setCurrentPrice(exchange, Trade.Symbol("BTCUSDT"), Trade.Price(50000.0))
      let result = PaperExchange.getMarketPrice(exchange, Trade.Symbol("BTCUSDT"), Trade.Market)
      switch result {
      | Ok(Trade.Price(p)) => expect(p)->toBe(50000.0)
      | Error(_) => expect(true)->toBe(false)
      }
    })

    it("returns error when no price set", () => {
      let exchange = makeExchange()
      let result = PaperExchange.getMarketPrice(exchange, Trade.Symbol("UNKNOWN"), Trade.Market)
      switch result {
      | Error(_) => expect(true)->toBe(true)
      | Ok(_) => expect(true)->toBe(false)
      }
    })

    it("uses limit price when order type is Limit", () => {
      let exchange = makeExchange()
      PaperExchange.setCurrentPrice(exchange, Trade.Symbol("BTCUSDT"), Trade.Price(50000.0))
      let result = PaperExchange.getMarketPrice(
        exchange,
        Trade.Symbol("BTCUSDT"),
        Trade.Limit({limitPrice: Trade.Price(49000.0)}),
      )
      switch result {
      | Ok(Trade.Price(p)) => expect(p)->toBe(49000.0)
      | Error(_) => expect(true)->toBe(false)
      }
    })
  })

  describe("placeOrder", () => {
    itAsync("executes a buy order and deducts balance", async () => {
      let exchange = makeExchange()
      PaperExchange.setCurrentPrice(exchange, Trade.Symbol("BTCUSDT"), Trade.Price(100.0))
      let result = await PaperExchange.placeOrder(
        exchange,
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Trade.Buy,
        ~orderType=Trade.Market,
        ~qty=Trade.Quantity(10.0),
      )
      switch result {
      | Ok(trade) =>
        switch trade.status {
        | Trade.Filled({filledPrice: Trade.Price(fp)}) => expect(fp)->toBe(100.0)
        | _ => expect(true)->toBe(false)
        }
        let Config.Balance(bal) = exchange.state.balance
        expect(bal)->toBe(9000.0)
      | Error(_) => expect(true)->toBe(false)
      }
    })

    itAsync("executes a sell order and adds to balance", async () => {
      let exchange = makeExchange()
      PaperExchange.setCurrentPrice(exchange, Trade.Symbol("BTCUSDT"), Trade.Price(100.0))
      let result = await PaperExchange.placeOrder(
        exchange,
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Trade.Sell,
        ~orderType=Trade.Market,
        ~qty=Trade.Quantity(5.0),
      )
      switch result {
      | Ok(_) =>
        let Config.Balance(bal) = exchange.state.balance
        expect(bal)->toBe(10500.0)
      | Error(_) => expect(true)->toBe(false)
      }
    })

    itAsync("rejects buy when insufficient balance", async () => {
      let exchange = makeExchange()
      PaperExchange.setCurrentPrice(exchange, Trade.Symbol("BTCUSDT"), Trade.Price(50000.0))
      let result = await PaperExchange.placeOrder(
        exchange,
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Trade.Buy,
        ~orderType=Trade.Market,
        ~qty=Trade.Quantity(1.0),
      )
      switch result {
      | Error(BotError.ExchangeError(InsufficientBalance(_))) => expect(true)->toBe(true)
      | _ => expect(true)->toBe(false)
      }
    })

    itAsync("generates unique trade IDs", async () => {
      let exchange = makeExchange()
      PaperExchange.setCurrentPrice(exchange, Trade.Symbol("BTCUSDT"), Trade.Price(10.0))
      let r1 = await PaperExchange.placeOrder(
        exchange,
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Trade.Buy,
        ~orderType=Trade.Market,
        ~qty=Trade.Quantity(1.0),
      )
      let r2 = await PaperExchange.placeOrder(
        exchange,
        ~symbol=Trade.Symbol("BTCUSDT"),
        ~side=Trade.Buy,
        ~orderType=Trade.Market,
        ~qty=Trade.Quantity(1.0),
      )
      switch (r1, r2) {
      | (Ok(t1), Ok(t2)) => expect(t1.id)->not_->notToBe(t2.id)
      | _ => expect(true)->toBe(false)
      }
    })

    itAsync("records trades in state", async () => {
      let exchange = makeExchange()
      PaperExchange.setCurrentPrice(exchange, Trade.Symbol("ETHUSDT"), Trade.Price(50.0))
      let _ = await PaperExchange.placeOrder(
        exchange,
        ~symbol=Trade.Symbol("ETHUSDT"),
        ~side=Trade.Buy,
        ~orderType=Trade.Market,
        ~qty=Trade.Quantity(2.0),
      )
      expect(exchange.state.trades->Array.length)->toBe(1)
      let firstTrade = exchange.state.trades->Array.getUnsafe(0)
      expect(firstTrade.symbol)->toBe(Trade.Symbol("ETHUSDT"))
    })
  })

  describe("trimTrades", () => {
    it("trims trades when exceeding 1000", () => {
      let exchange = makeExchange()
      let dummyTrade: Trade.trade = {
        id: Trade.TradeId("dummy"),
        symbol: Trade.Symbol("TEST"),
        side: Trade.Buy,
        orderType: Trade.Market,
        requestedQty: Trade.Quantity(1.0),
        status: Trade.Pending,
        createdAt: Trade.Timestamp(0.0),
      }
      exchange.state.trades = Array.make(~length=1001, dummyTrade)
      PaperExchange.trimTrades(exchange)
      expect(exchange.state.trades->Array.length)->toBe(1000)
    })
  })
})
