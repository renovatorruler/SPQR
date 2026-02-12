// Strategy configuration display — QFL parameters

let reentryToString = (reentry: Config.reentryPolicy): string => {
  switch reentry {
  | Config.NoReentry => "No re-entry"
  | Config.ReentryOnce({cooldown}) =>
    let Config.CooldownCandles(c) = cooldown
    `Once after ${c->Int.toString} candles`
  }
}

let setupEvalToString = (eval: Config.setupEvaluation): string => {
  switch eval {
  | Config.Disabled => "Disabled"
  | Config.Committee(_) => "Committee enabled"
  }
}

// Individual config row — label + value pair
module ConfigRow = {
  @react.component
  let make = (~label: string, ~value: string, ~icon: string="circle", ~valueColor: LiftKit.color=#onsurface) => {
    <div>
      <LiftKit.Text fontClass=#"caption-bold" color=#onsurfacevariant>
        {React.string(label)}
      </LiftKit.Text>
      <LiftKit.Row alignItems=#center gap=#"2xs">
        <LiftKit.Icon name=icon fontClass=#body color=valueColor />
        <LiftKit.Text fontClass=#body> {React.string(value)} </LiftKit.Text>
      </LiftKit.Row>
    </div>
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

  <LiftKit.Card variant=#fill bgColor=#surfacecontainerlow>
    <div className="spqr-section-gap">
      <LiftKit.Row alignItems=#center gap=#xs>
        <LiftKit.Icon name="settings" fontClass=#title2 color=#onsurfacevariant />
        <LiftKit.Heading tag=#h3 fontClass=#"heading-bold">
          {React.string("Strategy Parameters")}
        </LiftKit.Heading>
      </LiftKit.Row>
      <div className="spqr-config-grid">
        <ConfigRow
          label="Crack Threshold"
          value={`${crack->Float.toFixed(~digits=2)}%`}
          icon="zap"
        />
        <ConfigRow
          label="Base Filter"
          value={`${minBounces->Int.toString} bounces, ${tol->Float.toFixed(~digits=2)}% tol, ${drift->Float.toFixed(~digits=2)}% drift`}
          icon="filter"
        />
        <ConfigRow
          label="Stop Loss"
          value={`${stopLoss->Float.toFixed(~digits=2)}%`}
          icon="shield-alert"
          valueColor=#error
        />
        <ConfigRow
          label="Take Profit"
          value={`${tp->Float.toFixed(~digits=2)}%`}
          icon="target"
          valueColor=#primary
        />
        <ConfigRow
          label="Max Hold"
          value={`${maxHold->Int.toString} candles`}
          icon="clock"
        />
        <ConfigRow
          label="Re-entry"
          value={config.reentry->reentryToString}
          icon="rotate-ccw"
        />
        <ConfigRow
          label="Regime Gate"
          value={`EMA ${emaFast->Int.toString}/${emaSlow->Int.toString}, slope ${slopeLookback->Int.toString}`}
          icon="shield"
        />
        <ConfigRow
          label="LLM Evaluation"
          value={config.setupEvaluation->setupEvalToString}
          icon="brain"
        />
        <ConfigRow
          label="Lookback"
          value={`${lookback->Int.toString} candles`}
          icon="eye"
        />
      </div>
    </div>
  </LiftKit.Card>
}
