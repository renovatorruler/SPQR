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
  | Offline => "onsurfacevariant"
  | BotError(_) => "error"
  }
}

let botStatusDotClass = (status: botStatus): string => {
  switch status {
  | Online => "spqr-status-dot spqr-status-dot--online"
  | Offline => "spqr-status-dot spqr-status-dot--offline"
  | BotError(_) => "spqr-status-dot spqr-status-dot--error"
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

  <div className="spqr-section-gap">
    <LiftKit.Row alignItems="center" gap="xs">
      <LiftKit.Icon name="layout-dashboard" fontClass="title2" color="onsurfacevariant" />
      <LiftKit.Heading tag="h2" fontClass="title1-bold">
        {React.string("Dashboard")}
      </LiftKit.Heading>
    </LiftKit.Row>
    {switch data {
    | Loading =>
      <LiftKit.Card variant="outline">
        <LiftKit.Text fontClass="body" color="onsurfacevariant">
          {React.string("Loading dashboard...")}
        </LiftKit.Text>
      </LiftKit.Card>
    | FailedToLoad({reason}) =>
      <LiftKit.Card variant="outline" bgColor="errorcontainer">
        <LiftKit.Text fontClass="body" color="onerrorcontainer">
          {React.string(`Failed to load: ${reason}`)}
        </LiftKit.Text>
      </LiftKit.Card>
    | Loaded({totalPnl, activePositions, botStatus}) =>
      let Position.Pnl(pnlValue) = totalPnl
      let pnlColor = pnlValue >= 0.0 ? "primary" : "error"
      <LiftKit.Grid columns=3 gap="md" autoResponsive=true>
        <LiftKit.Card variant="fill" bgColor="surfacecontainerlow">
          <div className="spqr-metric-card">
            <LiftKit.Text fontClass="caption-bold" color="onsurfacevariant">
              {React.string("Total P&L")}
            </LiftKit.Text>
            <LiftKit.Heading tag="h3" fontClass="title1-bold" fontColor=pnlColor>
              {React.string(`$${pnlValue->Float.toString}`)}
            </LiftKit.Heading>
          </div>
        </LiftKit.Card>
        <LiftKit.Card variant="fill" bgColor="surfacecontainerlow">
          <div className="spqr-metric-card">
            <LiftKit.Text fontClass="caption-bold" color="onsurfacevariant">
              {React.string("Active Positions")}
            </LiftKit.Text>
            <LiftKit.Heading tag="h3" fontClass="title1-bold">
              {React.string(activePositions->Int.toString)}
            </LiftKit.Heading>
          </div>
        </LiftKit.Card>
        <LiftKit.Card variant="fill" bgColor="surfacecontainerlow">
          <div className="spqr-metric-card">
            <LiftKit.Text fontClass="caption-bold" color="onsurfacevariant">
              {React.string("Bot Status")}
            </LiftKit.Text>
            <LiftKit.Row alignItems="center" gap="2xs">
              <span className={botStatus->botStatusDotClass} />
              <LiftKit.Heading tag="h3" fontClass="title1-bold" fontColor={botStatus->botStatusColor}>
                {React.string(botStatus->botStatusToString)}
              </LiftKit.Heading>
            </LiftKit.Row>
          </div>
        </LiftKit.Card>
      </LiftKit.Grid>
    }}
  </div>
}
