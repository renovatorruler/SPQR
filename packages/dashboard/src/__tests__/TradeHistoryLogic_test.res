open Vitest

// Pure logic tests for TradeHistory.res
// Tests trade formatting functions — no DOM needed

describe("TradeHistory.sideToString", () => {
  it("returns 'BUY' for Buy", () => {
    TradeHistory.sideToString(Trade.Buy)->expect->toBe("BUY")
  })

  it("returns 'SELL' for Sell", () => {
    TradeHistory.sideToString(Trade.Sell)->expect->toBe("SELL")
  })
})

describe("TradeHistory.sideClassName", () => {
  it("maps Buy to buy class", () => {
    TradeHistory.sideClassName(Trade.Buy)->expect->toBe("spqr-side-buy")
  })

  it("maps Sell to sell class", () => {
    TradeHistory.sideClassName(Trade.Sell)->expect->toBe("spqr-side-sell")
  })
})

describe("TradeHistory.orderTypeToString", () => {
  it("returns 'Market' for Market", () => {
    TradeHistory.orderTypeToString(Trade.Market)->expect->toBe("Market")
  })

  it("returns formatted limit string with price", () => {
    TradeHistory.orderTypeToString(Limit({limitPrice: Trade.Price(42500.75)}))->expect->toBe(
      "Limit @ $42500.75",
    )
  })

  it("handles zero limit price", () => {
    TradeHistory.orderTypeToString(Limit({limitPrice: Trade.Price(0.0)}))->expect->toBe(
      "Limit @ $0",
    )
  })
})

describe("TradeHistory.statusToString", () => {
  it("returns 'Pending' for Pending", () => {
    TradeHistory.statusToString(Trade.Pending)->expect->toBe("Pending")
  })

  it("formats Filled with price", () => {
    TradeHistory.statusToString(
      Filled({filledAt: Trade.Timestamp(0.0), filledPrice: Trade.Price(100.5)}),
    )->expect->toBe("Filled @ $100.5")
  })

  it("formats PartiallyFilled with quantities", () => {
    TradeHistory.statusToString(
      PartiallyFilled({
        filledQty: Trade.Quantity(3.0),
        remainingQty: Trade.Quantity(7.0),
        avgPrice: Trade.Price(50.0),
      }),
    )->expect->toBe("Partial: 3/10")
  })

  it("formats Cancelled with reason", () => {
    TradeHistory.statusToString(
      Cancelled({cancelledAt: Trade.Timestamp(0.0), reason: "user requested"}),
    )->expect->toBe("Cancelled: user requested")
  })

  it("formats Rejected with reason", () => {
    TradeHistory.statusToString(
      Rejected({rejectedAt: Trade.Timestamp(0.0), reason: "insufficient balance"}),
    )->expect->toBe("Rejected: insufficient balance")
  })

  it("handles empty cancellation reason", () => {
    TradeHistory.statusToString(
      Cancelled({cancelledAt: Trade.Timestamp(0.0), reason: ""}),
    )->expect->toBe("Cancelled: ")
  })

  it("handles zero-fill partial (all remaining)", () => {
    TradeHistory.statusToString(
      PartiallyFilled({
        filledQty: Trade.Quantity(0.0),
        remainingQty: Trade.Quantity(5.0),
        avgPrice: Trade.Price(100.0),
      }),
    )->expect->toBe("Partial: 0/5")
  })
})

describe("TradeHistory.formatTimestamp", () => {
  it("converts epoch 0 to ISO string", () => {
    let result = TradeHistory.formatTimestamp(Trade.Timestamp(0.0))
    result->expect->toBe("1970-01-01T00:00:00.000Z")
  })

  it("converts known timestamp to ISO string", () => {
    // 2024-01-15T12:00:00.000Z = 1705320000000ms
    let result = TradeHistory.formatTimestamp(Trade.Timestamp(1705320000000.0))
    result->expect->toBe("2024-01-15T12:00:00.000Z")
  })
})
