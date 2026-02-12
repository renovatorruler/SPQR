// Backtest equity curve placeholder

@react.component
let make = (~equity: array<Backtest.equityPoint>) => {
  let points = equity->Array.length

  <LiftKit.Section py="md">
    <LiftKit.Heading tag="h2" fontClass="title1-bold">
      {React.string("Equity Curve")}
    </LiftKit.Heading>
    <LiftKit.Card>
      <LiftKit.Text fontClass="body" color="on-surface-variant">
        {React.string(`Equity points: ${points->Int.toString}`)}
      </LiftKit.Text>
      <div className="h-40 w-full rounded-md bg-[var(--lk-surface-variant)]" />
    </LiftKit.Card>
  </LiftKit.Section>
}
