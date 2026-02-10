// Root application component — LiftKit styled

@react.component
let make = () => {
  let sampleTrades: array<Trade.trade> = []

  <LiftKit.Container maxWidth="lg">
    <LiftKit.Section py="lg">
      <LiftKit.Row alignItems="center" justifyContent="space-between">
        <LiftKit.Heading tag="h1" fontClass="display1-bold">
          {React.string("SPQR Trading Bot")}
        </LiftKit.Heading>
        <LiftKit.Badge icon="activity" color="primary" />
      </LiftKit.Row>
    </LiftKit.Section>
    <Dashboard />
    <LiftKit.Section py="md">
      <TradeHistory trades=sampleTrades />
    </LiftKit.Section>
  </LiftKit.Container>
}
