// Backtest summary metrics

@react.component
let make = (~metrics: Backtest.metrics) => {
  let Backtest.TradeCount(trades) = metrics.totalTrades
  let Backtest.WinRate(winRate) = metrics.winRate
  let Backtest.ReturnPercent(totalReturn) = metrics.totalReturn
  let Backtest.DrawdownPercent(maxDd) = metrics.maxDrawdown

  <LiftKit.Section py="md">
    <LiftKit.Heading tag="h2" fontClass="title1-bold">
      {React.string("Backtest Summary")}
    </LiftKit.Heading>
    <LiftKit.Grid columns=4 gap="md" autoResponsive=true>
      <LiftKit.Card>
        <LiftKit.Text fontClass="label-bold" color="on-surface-variant">
          {React.string("Total Return")}
        </LiftKit.Text>
        <LiftKit.Heading tag="h3" fontClass="display2-bold">
          {React.string(`${totalReturn->Float.toFixed(~digits=2)}%`)}
        </LiftKit.Heading>
      </LiftKit.Card>
      <LiftKit.Card>
        <LiftKit.Text fontClass="label-bold" color="on-surface-variant">
          {React.string("Max Drawdown")}
        </LiftKit.Text>
        <LiftKit.Heading tag="h3" fontClass="display2-bold" fontColor="error">
          {React.string(`${maxDd->Float.toFixed(~digits=2)}%`)}
        </LiftKit.Heading>
      </LiftKit.Card>
      <LiftKit.Card>
        <LiftKit.Text fontClass="label-bold" color="on-surface-variant">
          {React.string("Win Rate")}
        </LiftKit.Text>
        <LiftKit.Heading tag="h3" fontClass="display2-bold">
          {React.string(`${(winRate *. 100.0)->Float.toFixed(~digits=1)}%`)}
        </LiftKit.Heading>
      </LiftKit.Card>
      <LiftKit.Card>
        <LiftKit.Text fontClass="label-bold" color="on-surface-variant">
          {React.string("Total Trades")}
        </LiftKit.Text>
        <LiftKit.Heading tag="h3" fontClass="display2-bold">
          {React.string(trades->Int.toString)}
        </LiftKit.Heading>
      </LiftKit.Card>
    </LiftKit.Grid>
  </LiftKit.Section>
}
