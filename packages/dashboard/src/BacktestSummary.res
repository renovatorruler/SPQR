// Backtest summary metrics — key performance indicators

@react.component
let make = (~metrics: Backtest.metrics) => {
  let Backtest.TradeCount(trades) = metrics.totalTrades
  let Backtest.WinRate(winRate) = metrics.winRate
  let Backtest.ReturnPercent(totalReturn) = metrics.totalReturn
  let Backtest.DrawdownPercent(maxDd) = metrics.maxDrawdown

  let returnColor = totalReturn >= 0.0 ? #primary : #error

  <div className="spqr-section-gap">
    <SectionHeader title="Backtest Summary" icon="bar-chart-3" />
    <LiftKit.Grid columns=4 gap=#md autoResponsive=true>
      <MetricCard
        label="Total Return"
        value={`${totalReturn->Float.toFixed(~digits=2)}%`}
        fontColor=returnColor
      />
      <MetricCard
        label="Max Drawdown"
        value={`${maxDd->Float.toFixed(~digits=2)}%`}
        fontColor=#error
      />
      <MetricCard
        label="Win Rate"
        value={`${(winRate *. 100.0)->Float.toFixed(~digits=1)}%`}
      />
      <MetricCard
        label="Total Trades"
        value={trades->Int.toString}
      />
    </LiftKit.Grid>
  </div>
}
