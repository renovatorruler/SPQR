// Backtest trades — wraps TradeHistory with contextual heading

@react.component
let make = (~trades: array<Trade.trade>) => {
  <LiftKit.Card variant=#fill bgColor=#surfacecontainerlow>
    <div className="spqr-section-gap">
      <SectionHeader title="Backtest Trades" icon="history" level=Section />
      <TradeHistory trades showHeading=false />
    </div>
  </LiftKit.Card>
}
