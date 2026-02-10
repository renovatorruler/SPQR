// Dashboard overview component — P&L, positions, bot status

// Variants over booleans (Manifesto Principle 2)
type botStatus =
  | Online
  | Offline
  | BotError({message: string})

let botStatusToString = (status: botStatus): string => {
  switch status {
  | Online => "Online"
  | Offline => "Offline"
  | BotError({message}) => `Error: ${message}`
  }
}

// No default values (Manifesto Principle 3)
// Dashboard state is explicit about what data is available
type dashboardData =
  | Loading
  | Loaded({
      totalPnl: Position.pnl,
      activePositions: int,
      botStatus: botStatus,
    })
  | FailedToLoad({reason: string})

@react.component
let make = () => {
  // Placeholder: hardcoded sample data
  let data = Loaded({
    totalPnl: Position.Pnl(0.0),
    activePositions: 0,
    botStatus: Offline,
  })

  <section>
    <h2>{React.string("Dashboard")}</h2>
    {switch data {
    | Loading => <p>{React.string("Loading dashboard...")}</p>
    | FailedToLoad({reason}) => <p>{React.string(`Failed to load: ${reason}`)}</p>
    | Loaded({totalPnl, activePositions, botStatus}) =>
      let Position.Pnl(pnlValue) = totalPnl
      <div>
        <div>
          <h3>{React.string("Total P&L")}</h3>
          <p>{React.string(`$${pnlValue->Float.toString}`)}</p>
        </div>
        <div>
          <h3>{React.string("Active Positions")}</h3>
          <p>{React.string(activePositions->Int.toString)}</p>
        </div>
        <div>
          <h3>{React.string("Bot Status")}</h3>
          <p>{React.string(botStatus->botStatusToString)}</p>
        </div>
      </div>
    }}
  </section>
}
