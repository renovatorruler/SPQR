open Vitest

// Tests for ApiHooks.decodeTrade — the JSON → domain type decoder

let makeTrade = (
  ~id: string,
  ~symbol: string="BTCUSDT",
  ~side: string="buy",
  ~orderType: string="market",
  ~qty: float=1.0,
  ~status: string="filled",
  ~filledPrice: Nullable.t<float>=Nullable.make(100.0),
  ~filledAt: Nullable.t<float>=Nullable.make(100.0),
  ~createdAt: float=100.0,
): ApiHooks.tradeResponse => {
  {
    id,
    symbol,
    side,
    orderType,
    requestedQty: qty,
    status,
    filledPrice,
    filledAt,
    createdAt,
  }
}

describe("ApiHooks.decodeTrade", () => {
  it("decodes a filled buy trade", () => {
    let raw = makeTrade(~id="t-1", ~side="buy", ~qty=0.5, ~filledPrice=Nullable.make(42000.0))
    let result = ApiHooks.decodeTrade(raw)
    expect(result->Option.isSome)->toBe(true)
    let trade = result->Option.getOrThrow
    let Trade.TradeId(id) = trade.id
    expect(id)->toBe("t-1")
    let Trade.Symbol(sym) = trade.symbol
    expect(sym)->toBe("BTCUSDT")
    expect(trade.side == Trade.Buy)->toBe(true)
    expect(trade.orderType == Trade.Market)->toBe(true)
    let Trade.Quantity(q) = trade.requestedQty
    expect(q)->toBe(0.5)
  })

  it("decodes a sell trade", () => {
    let raw = makeTrade(~id="t-2", ~symbol="ETHUSDT", ~side="sell")
    let trade = ApiHooks.decodeTrade(raw)->Option.getOrThrow
    expect(trade.side == Trade.Sell)->toBe(true)
  })

  it("decodes a pending trade", () => {
    let raw = makeTrade(
      ~id="t-3",
      ~status="pending",
      ~filledPrice=Nullable.null,
      ~filledAt=Nullable.null,
    )
    let trade = ApiHooks.decodeTrade(raw)->Option.getOrThrow
    expect(trade.status == Trade.Pending)->toBe(true)
  })

  it("decodes a cancelled trade", () => {
    let raw = makeTrade(
      ~id="t-4",
      ~side="sell",
      ~status="cancelled",
      ~filledPrice=Nullable.null,
      ~filledAt=Nullable.null,
    )
    expect(ApiHooks.decodeTrade(raw)->Option.isSome)->toBe(true)
  })

  it("decodes a rejected trade", () => {
    let raw = makeTrade(
      ~id="t-5",
      ~status="rejected",
      ~filledPrice=Nullable.null,
      ~filledAt=Nullable.null,
    )
    expect(ApiHooks.decodeTrade(raw)->Option.isSome)->toBe(true)
  })

  it("returns None for invalid side", () => {
    let raw = makeTrade(~id="t-6", ~side="invalid")
    expect(ApiHooks.decodeTrade(raw)->Option.isNone)->toBe(true)
  })

  it("returns None for invalid order type", () => {
    let raw = makeTrade(~id="t-7", ~orderType="unknown")
    expect(ApiHooks.decodeTrade(raw)->Option.isNone)->toBe(true)
  })

  it("returns None for invalid status", () => {
    let raw = makeTrade(~id="t-8", ~status="unknown_status")
    expect(ApiHooks.decodeTrade(raw)->Option.isNone)->toBe(true)
  })

  it("decodes a limit order with filled price", () => {
    let raw = makeTrade(
      ~id="t-9",
      ~orderType="limit",
      ~status="pending",
      ~filledPrice=Nullable.make(45000.0),
      ~filledAt=Nullable.null,
    )
    let trade = ApiHooks.decodeTrade(raw)->Option.getOrThrow
    switch trade.orderType {
    | Trade.Limit({limitPrice}) =>
      let Trade.Price(p) = limitPrice
      expect(p)->toBe(45000.0)
    | _ => expect(true)->toBe(false)
    }
  })

  it("decodes limit order without price as Market fallback", () => {
    let raw = makeTrade(
      ~id="t-10",
      ~orderType="limit",
      ~status="pending",
      ~filledPrice=Nullable.null,
      ~filledAt=Nullable.null,
    )
    let trade = ApiHooks.decodeTrade(raw)->Option.getOrThrow
    expect(trade.orderType == Trade.Market)->toBe(true)
  })
})

describe("Dashboard.regimeToStatus", () => {
  it("maps 'unknown' to Offline", () => {
    let status = Dashboard.regimeToStatus("unknown")
    expect(status == Dashboard.Offline)->toBe(true)
  })

  it("maps any other regime to Online", () => {
    let status = Dashboard.regimeToStatus("ranging")
    expect(status == Dashboard.Online)->toBe(true)
  })

  it("maps trending_up to Online", () => {
    let status = Dashboard.regimeToStatus("trending_up")
    expect(status == Dashboard.Online)->toBe(true)
  })
})
