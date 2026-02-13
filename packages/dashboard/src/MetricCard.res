// Metric card — label + value display used in Dashboard and BacktestSummary
//
// Two construction modes:
//   MetricCard.make(~label, ~value="$123")         → wraps in h3 heading
//   MetricCard.make(~label, ~children=<custom />)  → renders children as-is
//
// This handles both simple text metrics and composite values
// (e.g. status dot + label in Bot Status card) without double-wrapping.

@react.component
let make = (
  ~label: string,
  ~value: option<string>=?,
  ~fontColor: option<LiftKit.color>=?,
  ~children: option<React.element>=?,
) => {
  <LiftKit.Card variant=#fill bgColor=#surfacecontainerlow>
    <div className="spqr-metric-card">
      <LiftKit.Text fontClass=#"caption-bold" color=#onsurfacevariant>
        {React.string(label)}
      </LiftKit.Text>
      {switch (value, children) {
      | (Some(v), _) =>
        <LiftKit.Heading tag=#h3 fontClass=#"title1-bold" ?fontColor>
          {React.string(v)}
        </LiftKit.Heading>
      | (None, Some(c)) => c
      | (None, None) => React.null
      }}
    </div>
  </LiftKit.Card>
}
