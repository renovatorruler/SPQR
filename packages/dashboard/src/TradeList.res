@react.component
let make = () => {
  <div
    style={{
      marginTop: "24px",
      background: "#1a1a1a",
      padding: "20px",
      borderRadius: "8px",
      border: "1px solid #2a2a2a",
    }}>
    <h2 style={{fontSize: "18px", marginBottom: "12px"}}>
      {React.string("Trade History")}
    </h2>
    <div style={{color: "#888", textAlign: "center", padding: "24px"}}>
      {React.string("No trades yet.")}
    </div>
  </div>
}
