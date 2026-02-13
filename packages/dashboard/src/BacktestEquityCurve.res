// Backtest equity curve placeholder — charting lib TBD

@react.component
let make = (~equity: array<Backtest.equityPoint>) => {
  let points = equity->Array.length

  <div className="spqr-section-gap">
    <SectionHeader title="Equity Curve" icon="trending-up" />
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
