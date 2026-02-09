// Trade history table component

// Explicit empty state (Manifesto Principle 3 — no default empty array)
type tradeListState =
  | NoTrades
  | HasTrades({trades: array<Trade.trade>})

let sideToString = (side: Trade.side): string => {
  switch side {
  | Buy => "BUY"
  | Sell => "SELL"
  }
}

let orderTypeToString = (orderType: Trade.orderType): string => {
  switch orderType {
  | Market => "Market"
  | Limit({limitPrice}) =>
    let Trade.Price(p) = limitPrice
    `Limit @ $${p->Float.toString}`
  }
}

let statusToString = (status: Trade.tradeStatus): string => {
  switch status {
  | Pending => "Pending"
  | Filled({filledPrice}) =>
    let Trade.Price(p) = filledPrice
    `Filled @ $${p->Float.toString}`
  | PartiallyFilled({filledQty, remainingQty}) =>
    let Trade.Quantity(filled) = filledQty
    let Trade.Quantity(remaining) = remainingQty
    `Partial: ${filled->Float.toString}/${(filled +. remaining)->Float.toString}`
  | Cancelled({reason}) => `Cancelled: ${reason}`
  | Rejected({reason}) => `Rejected: ${reason}`
  }
}

let formatTimestamp = (ts: Trade.timestamp): string => {
  let Trade.Timestamp(ms) = ts
  let date = Date.fromTime(ms)
  date->Date.toISOString
}

@react.component
let make = (~trades: array<Trade.trade>) => {
  let state = switch trades->Array.length {
  | 0 => NoTrades
  | _ => HasTrades({trades: trades})
  }

  <section>
    <h2>{React.string("Trade History")}</h2>
    {switch state {
    | NoTrades =>
      <p>{React.string("No trades yet. The bot has not executed any trades.")}</p>
    | HasTrades({trades}) =>
      <table>
        <thead>
          <tr>
            <th>{React.string("Time")}</th>
            <th>{React.string("Symbol")}</th>
            <th>{React.string("Side")}</th>
            <th>{React.string("Type")}</th>
            <th>{React.string("Qty")}</th>
            <th>{React.string("Status")}</th>
          </tr>
        </thead>
        <tbody>
          {trades
          ->Array.map(trade => {
            let Trade.TradeId(id) = trade.id
            let Trade.Symbol(sym) = trade.symbol
            let Trade.Quantity(qty) = trade.requestedQty
            <tr key=id>
              <td>{React.string(trade.createdAt->formatTimestamp)}</td>
              <td>{React.string(sym)}</td>
              <td>{React.string(trade.side->sideToString)}</td>
              <td>{React.string(trade.orderType->orderTypeToString)}</td>
              <td>{React.string(qty->Float.toString)}</td>
              <td>{React.string(trade.status->statusToString)}</td>
            </tr>
          })
          ->React.array}
        </tbody>
      </table>
    }}
  </section>
}
