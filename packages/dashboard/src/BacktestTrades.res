// Backtest trades table

@react.component
let make = (~trades: array<Trade.trade>) => {
  <LiftKit.Section py="md">
    <LiftKit.Heading tag="h2" fontClass="title1-bold">
      {React.string("Backtest Trades")}
    </LiftKit.Heading>
    <TradeHistory trades />
  </LiftKit.Section>
}
