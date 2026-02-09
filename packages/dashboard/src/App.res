// Root application component

@react.component
let make = () => {
  // Sample data for initial rendering
  let sampleTrades: array<Trade.trade> = []

  <div>
    <header>
      <h1>{React.string("SPQR Trading Bot")}</h1>
    </header>
    <main>
      <Dashboard />
      <TradeHistory trades=sampleTrades />
    </main>
  </div>
}
