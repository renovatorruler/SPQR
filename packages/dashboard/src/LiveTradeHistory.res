// Live trade history — SWR-powered wrapper around TradeHistory
//
// Fetches trades from /api/trades and renders them in the TradeHistory table.
// Shows loading/error states while the API call is in flight.

@react.component
let make = () => {
  let tradesState = ApiHooks.useTrades()

  switch tradesState {
  | ApiHooks.Loading =>
    <div className="spqr-section-gap">
      <SectionHeader title="Trade History" icon="list" />
      <LiftKit.Card variant=#outline>
        <LiftKit.Text fontClass=#body color=#onsurfacevariant>
          {React.string("Loading trades...")}
        </LiftKit.Text>
      </LiftKit.Card>
    </div>
  | ApiHooks.Failed({message}) =>
    <div className="spqr-section-gap">
      <SectionHeader title="Trade History" icon="list" />
      <LiftKit.Card variant=#outline bgColor=#errorcontainer>
        <LiftKit.Text fontClass=#body color=#onerrorcontainer>
          {React.string(`Failed to load trades: ${message}`)}
        </LiftKit.Text>
      </LiftKit.Card>
    </div>
  | ApiHooks.Loaded({trades}) => <TradeHistory trades />
  }
}
