// Backtest summary metrics — key performance indicators

@react.component
let make = (~metrics: Backtest.metrics) => {
  let Backtest.TradeCount(trades) = metrics.totalTrades
  let Backtest.WinRate(winRate) = metrics.winRate
  let Backtest.ReturnPercent(totalReturn) = metrics.totalReturn
  let Backtest.DrawdownPercent(maxDd) = metrics.maxDrawdown

  let returnColor = totalReturn >= 0.0 ? "primary" : "error"

  <div className="spqr-section-gap">
    <LiftKit.Row alignItems="center" gap="xs">
      <LiftKit.Icon name="bar-chart-3" fontClass="title2" color="onsurfacevariant" />
      <LiftKit.Heading tag="h2" fontClass="title1-bold">
        {React.string("Backtest Summary")}
      </LiftKit.Heading>
    </LiftKit.Row>
    <LiftKit.Grid columns=4 gap="md" autoResponsive=true>
      <LiftKit.Card variant="fill" bgColor="surfacecontainerlow">
        <div className="spqr-metric-card">
          <LiftKit.Text fontClass="caption-bold" color="onsurfacevariant">
            {React.string("Total Return")}
          </LiftKit.Text>
          <LiftKit.Heading tag="h3" fontClass="title1-bold" fontColor=returnColor>
            {React.string(`${totalReturn->Float.toFixed(~digits=2)}%`)}
          </LiftKit.Heading>
        </div>
      </LiftKit.Card>
      <LiftKit.Card variant="fill" bgColor="surfacecontainerlow">
        <div className="spqr-metric-card">
          <LiftKit.Text fontClass="caption-bold" color="onsurfacevariant">
            {React.string("Max Drawdown")}
          </LiftKit.Text>
          <LiftKit.Heading tag="h3" fontClass="title1-bold" fontColor="error">
            {React.string(`${maxDd->Float.toFixed(~digits=2)}%`)}
          </LiftKit.Heading>
        </div>
      </LiftKit.Card>
      <LiftKit.Card variant="fill" bgColor="surfacecontainerlow">
        <div className="spqr-metric-card">
          <LiftKit.Text fontClass="caption-bold" color="onsurfacevariant">
            {React.string("Win Rate")}
          </LiftKit.Text>
          <LiftKit.Heading tag="h3" fontClass="title1-bold">
            {React.string(`${(winRate *. 100.0)->Float.toFixed(~digits=1)}%`)}
          </LiftKit.Heading>
        </div>
      </LiftKit.Card>
      <LiftKit.Card variant="fill" bgColor="surfacecontainerlow">
        <div className="spqr-metric-card">
          <LiftKit.Text fontClass="caption-bold" color="onsurfacevariant">
            {React.string("Total Trades")}
          </LiftKit.Text>
          <LiftKit.Heading tag="h3" fontClass="title1-bold">
            {React.string(trades->Int.toString)}
          </LiftKit.Heading>
        </div>
      </LiftKit.Card>
    </LiftKit.Grid>
  </div>
}
