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

  <>
    <LiftKit.Heading tag="h2" fontClass="title1-bold">
      {React.string("Trade History")}
    </LiftKit.Heading>
    {switch state {
    | NoTrades =>
      <LiftKit.Card variant="outline">
        <LiftKit.Text fontClass="body" color="on-surface-variant">
          {React.string("No trades yet. The bot has not executed any trades.")}
        </LiftKit.Text>
      </LiftKit.Card>
    | HasTrades({trades}) =>
      <LiftKit.Card>
        <table className="w-full">
          <thead>
            <tr>
              <th className="text-left">
                <LiftKit.Text tag="span" fontClass="label-bold" color="on-surface-variant">
                  {React.string("Time")}
                </LiftKit.Text>
              </th>
              <th className="text-left">
                <LiftKit.Text tag="span" fontClass="label-bold" color="on-surface-variant">
                  {React.string("Symbol")}
                </LiftKit.Text>
              </th>
              <th className="text-left">
                <LiftKit.Text tag="span" fontClass="label-bold" color="on-surface-variant">
                  {React.string("Side")}
                </LiftKit.Text>
              </th>
              <th className="text-left">
                <LiftKit.Text tag="span" fontClass="label-bold" color="on-surface-variant">
                  {React.string("Type")}
                </LiftKit.Text>
              </th>
              <th className="text-left">
                <LiftKit.Text tag="span" fontClass="label-bold" color="on-surface-variant">
                  {React.string("Qty")}
                </LiftKit.Text>
              </th>
              <th className="text-left">
                <LiftKit.Text tag="span" fontClass="label-bold" color="on-surface-variant">
                  {React.string("Status")}
                </LiftKit.Text>
              </th>
            </tr>
          </thead>
          <tbody>
            {trades
            ->Array.map(trade => {
              let Trade.TradeId(id) = trade.id
              let Trade.Symbol(sym) = trade.symbol
              let Trade.Quantity(qty) = trade.requestedQty
              <tr key=id>
                <td>
                  <LiftKit.Text tag="span" fontClass="body">
                    {React.string(trade.createdAt->formatTimestamp)}
                  </LiftKit.Text>
                </td>
                <td>
                  <LiftKit.Text tag="span" fontClass="body-bold">
                    {React.string(sym)}
                  </LiftKit.Text>
                </td>
                <td>
                  <LiftKit.Text tag="span" fontClass="body">
                    {React.string(trade.side->sideToString)}
                  </LiftKit.Text>
                </td>
                <td>
                  <LiftKit.Text tag="span" fontClass="body">
                    {React.string(trade.orderType->orderTypeToString)}
                  </LiftKit.Text>
                </td>
                <td>
                  <LiftKit.Text tag="span" fontClass="body">
                    {React.string(qty->Float.toString)}
                  </LiftKit.Text>
                </td>
                <td>
                  <LiftKit.Text tag="span" fontClass="body">
                    {React.string(trade.status->statusToString)}
                  </LiftKit.Text>
                </td>
              </tr>
            })
            ->React.array}
          </tbody>
        </table>
      </LiftKit.Card>
    }}
  </>
}
