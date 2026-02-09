@react.component
let make = () => {
  <div
    style={{
      background: "#1a1a1a",
      padding: "20px",
      borderRadius: "8px",
      border: "1px solid #2a2a2a",
    }}>
    <h2 style={{fontSize: "18px", marginBottom: "12px"}}>
      {React.string("P&L")}
    </h2>
    <div style={{fontSize: "28px", fontWeight: "bold", color: "#4ade80"}}>
      {React.string("$0.00")}
    </div>
  </div>
}
