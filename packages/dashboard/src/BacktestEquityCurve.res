// Backtest equity curve placeholder — charting lib TBD

@react.component
let make = (~equity: array<Backtest.equityPoint>) => {
  let points = equity->Array.length

  <div className="spqr-section-gap">
    <LiftKit.Row alignItems=#center gap=#xs>
      <LiftKit.Icon name="trending-up" fontClass=#title2 color=#onsurfacevariant />
      <LiftKit.Heading tag=#h2 fontClass=#"title1-bold">
        {React.string("Equity Curve")}
      </LiftKit.Heading>
    </LiftKit.Row>
    <LiftKit.Card variant=#fill bgColor=#surfacecontainerlow>
      <LiftKit.Text fontClass=#caption color=#onsurfacevariant>
        {React.string(`${points->Int.toString} equity points`)}
      </LiftKit.Text>
      <div className="spqr-equity-placeholder mt-sm">
        <LiftKit.Text fontClass=#body color=#onsurfacevariant>
          {React.string("Chart placeholder")}
        </LiftKit.Text>
      </div>
    </LiftKit.Card>
  </div>
}
