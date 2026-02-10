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

let botStatusColor = (status: botStatus): string => {
  switch status {
  | Online => "primary"
  | Offline => "on-surface-variant"
  | BotError(_) => "error"
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
  let data = Loaded({
    totalPnl: Position.Pnl(0.0),
    activePositions: 0,
    botStatus: Offline,
  })

  <LiftKit.Section py="md">
    <LiftKit.Heading tag="h2" fontClass="title1-bold">
      {React.string("Dashboard")}
    </LiftKit.Heading>
    {switch data {
    | Loading =>
      <LiftKit.Card>
        <LiftKit.Text fontClass="body"> {React.string("Loading dashboard...")} </LiftKit.Text>
      </LiftKit.Card>
    | FailedToLoad({reason}) =>
      <LiftKit.Card variant="outline">
        <LiftKit.Text fontClass="body" color="error">
          {React.string(`Failed to load: ${reason}`)}
        </LiftKit.Text>
      </LiftKit.Card>
    | Loaded({totalPnl, activePositions, botStatus}) =>
      let Position.Pnl(pnlValue) = totalPnl
      let pnlColor = pnlValue >= 0.0 ? "primary" : "error"
      <LiftKit.Grid columns=3 gap="md" autoResponsive=true>
        <LiftKit.Card>
          <LiftKit.Text fontClass="label-bold" color="on-surface-variant">
            {React.string("Total P&L")}
          </LiftKit.Text>
          <LiftKit.Heading tag="h3" fontClass="display2-bold" fontColor=pnlColor>
            {React.string(`$${pnlValue->Float.toString}`)}
          </LiftKit.Heading>
        </LiftKit.Card>
        <LiftKit.Card>
          <LiftKit.Text fontClass="label-bold" color="on-surface-variant">
            {React.string("Active Positions")}
          </LiftKit.Text>
          <LiftKit.Heading tag="h3" fontClass="display2-bold">
            {React.string(activePositions->Int.toString)}
          </LiftKit.Heading>
        </LiftKit.Card>
        <LiftKit.Card>
          <LiftKit.Text fontClass="label-bold" color="on-surface-variant">
            {React.string("Bot Status")}
          </LiftKit.Text>
          <LiftKit.Heading tag="h3" fontClass="display2-bold" fontColor={botStatus->botStatusColor}>
            {React.string(botStatus->botStatusToString)}
          </LiftKit.Heading>
        </LiftKit.Card>
      </LiftKit.Grid>
    }}
  </LiftKit.Section>
}
