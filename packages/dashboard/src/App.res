@react.component
let make = () => {
  <div style={{maxWidth: "1200px", margin: "0 auto", padding: "24px"}}>
    <h1 style={{fontSize: "24px", fontWeight: "bold", marginBottom: "24px"}}>
      {React.string("SPQR Trading Dashboard")}
    </h1>
    <div style={{display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px"}}>
      <PnLChart />
      <PositionPanel />
    </div>
    <TradeList />
  </div>
}
