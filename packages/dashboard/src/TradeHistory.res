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

let sideClassName = (side: Trade.side): string => {
  switch side {
  | Buy => "spqr-side-buy"
  | Sell => "spqr-side-sell"
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
let make = (~trades: array<Trade.trade>, ~showHeading: bool=true) => {
  let state = switch trades->Array.length {
  | 0 => NoTrades
  | _ => HasTrades({trades: trades})
  }

  <div className="spqr-section-gap">
    {if showHeading {
      <LiftKit.Row alignItems="center" gap="xs">
        <LiftKit.Icon name="list" fontClass="title2" color="onsurfacevariant" />
        <LiftKit.Heading tag="h2" fontClass="title1-bold">
          {React.string("Trade History")}
        </LiftKit.Heading>
      </LiftKit.Row>
    } else {
      React.null
    }}
    {switch state {
    | NoTrades =>
      <LiftKit.Card variant="outline">
        <LiftKit.Row alignItems="center" gap="sm">
          <LiftKit.Icon name="inbox" fontClass="body" color="onsurfacevariant" />
          <LiftKit.Text fontClass="body" color="onsurfacevariant">
            {React.string("No trades yet. The bot has not executed any trades.")}
          </LiftKit.Text>
        </LiftKit.Row>
      </LiftKit.Card>
    | HasTrades({trades}) =>
      <LiftKit.Card>
        <div className="spqr-table-scroll">
          <table className="spqr-table">
            <thead>
              <tr>
                <th>
                  <LiftKit.Text tag="span" fontClass="caption-bold" color="onsurfacevariant">
                    {React.string("Time")}
                  </LiftKit.Text>
                </th>
                <th>
                  <LiftKit.Text tag="span" fontClass="caption-bold" color="onsurfacevariant">
                    {React.string("Symbol")}
                  </LiftKit.Text>
                </th>
                <th>
                  <LiftKit.Text tag="span" fontClass="caption-bold" color="onsurfacevariant">
                    {React.string("Side")}
                  </LiftKit.Text>
                </th>
                <th>
                  <LiftKit.Text tag="span" fontClass="caption-bold" color="onsurfacevariant">
                    {React.string("Type")}
                  </LiftKit.Text>
                </th>
                <th>
                  <LiftKit.Text tag="span" fontClass="caption-bold" color="onsurfacevariant">
                    {React.string("Qty")}
                  </LiftKit.Text>
                </th>
                <th>
                  <LiftKit.Text tag="span" fontClass="caption-bold" color="onsurfacevariant">
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
                    <LiftKit.Text tag="span" fontClass="body-mono">
                      {React.string(trade.createdAt->formatTimestamp)}
                    </LiftKit.Text>
                  </td>
                  <td>
                    <LiftKit.Text tag="span" fontClass="body-bold">
                      {React.string(sym)}
                    </LiftKit.Text>
                  </td>
                  <td>
                    <span className={trade.side->sideClassName}>
                      {React.string(trade.side->sideToString)}
                    </span>
                  </td>
                  <td>
                    <LiftKit.Text tag="span" fontClass="body">
                      {React.string(trade.orderType->orderTypeToString)}
                    </LiftKit.Text>
                  </td>
                  <td>
                    <LiftKit.Text tag="span" fontClass="body-mono">
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
        </div>
      </LiftKit.Card>
    }}
  </div>
}
