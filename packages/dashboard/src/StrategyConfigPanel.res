// Strategy configuration display

let reentryToString = (reentry: Config.reentryPolicy): string => {
  switch reentry {
  | Config.NoReentry => "No re-entry"
  | Config.ReentryOnce({cooldown}) =>
    let Config.CooldownCandles(c) = cooldown
    `Re-enter once after ${c->Int.toString} candles`
  }
}

let setupEvalToString = (eval: Config.setupEvaluation): string => {
  switch eval {
  | Config.Disabled => "LLM evaluation disabled"
  | Config.Committee(_) => "LLM committee enabled"
  }
}

@react.component
let make = (~config: Config.qflConfig) => {
  let Config.CrackPercent(crack) = config.crackThreshold
  let Config.BounceCount(minBounces) = config.baseFilter.minBounces
  let Config.TolerancePercent(tol) = config.baseFilter.tolerance
  let Config.DriftPercent(drift) = config.baseFilter.maxBaseDrift
  let Config.StopLossPercent(stopLoss) = config.exitPolicy.stopLoss
  let Config.TakeProfitPercent(tp) = config.exitPolicy.takeProfit
  let Config.HoldCandles(maxHold) = config.exitPolicy.maxHold
  let Config.EmaPeriod(emaFast) = config.regimeGate.emaFast
  let Config.EmaPeriod(emaSlow) = config.regimeGate.emaSlow
  let Config.EmaSlopeLookback(slopeLookback) = config.regimeGate.emaSlopeLookback
  let Config.CandleCount(lookback) = config.lookbackCandles

  <LiftKit.Section py="md">
    <LiftKit.Heading tag="h2" fontClass="title1-bold">
      {React.string("Strategy Parameters")}
    </LiftKit.Heading>
    <LiftKit.Card>
      <LiftKit.Text fontClass="body">{React.string(`Crack threshold: ${crack->Float.toFixed(~digits=2)}%`)}</LiftKit.Text>
      <LiftKit.Text fontClass="body">{React.string(`Base filter: min bounces ${minBounces->Int.toString}, tolerance ${tol->Float.toFixed(~digits=2)}%, max drift ${drift->Float.toFixed(~digits=2)}%`)}</LiftKit.Text>
      <LiftKit.Text fontClass="body">{React.string(`Exit policy: stop ${stopLoss->Float.toFixed(~digits=2)}%, take profit ${tp->Float.toFixed(~digits=2)}%, max hold ${maxHold->Int.toString} candles`)}</LiftKit.Text>
      <LiftKit.Text fontClass="body">{React.string(`Re-entry: ${config.reentry->reentryToString}`)}</LiftKit.Text>
      <LiftKit.Text fontClass="body">{React.string(`Regime gate: EMA ${emaFast->Int.toString}/${emaSlow->Int.toString}, slope lookback ${slopeLookback->Int.toString}`)}</LiftKit.Text>
      <LiftKit.Text fontClass="body">{React.string(`LLM setup evaluation: ${config.setupEvaluation->setupEvalToString}`)}</LiftKit.Text>
      <LiftKit.Text fontClass="body">{React.string(`Lookback candles: ${lookback->Int.toString}`)}</LiftKit.Text>
    </LiftKit.Card>
  </LiftKit.Section>
}
