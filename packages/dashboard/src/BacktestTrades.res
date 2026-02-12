// Backtest trades — wraps TradeHistory with contextual heading

@react.component
let make = (~trades: array<Trade.trade>) => {
  <LiftKit.Card variant="fill" bgColor="surfacecontainerlow">
    <div className="spqr-section-gap">
      <LiftKit.Row alignItems="center" gap="xs">
        <LiftKit.Icon name="history" fontClass="title2" color="onsurfacevariant" />
        <LiftKit.Heading tag="h3" fontClass="heading-bold">
          {React.string("Backtest Trades")}
        </LiftKit.Heading>
      </LiftKit.Row>
      <TradeHistory trades showHeading=false />
    </div>
  </LiftKit.Card>
}
