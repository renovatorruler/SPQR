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

let botStatusColor = (status: botStatus): LiftKit.color => {
  switch status {
  | Online => #primary
  | Offline => #onsurfacevariant
  | BotError(_) => #error
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

// Map API regime string to bot status
// The regime field indicates the bot has been writing to the DB (i.e. it ran)
let regimeToStatus = (regime: string): botStatus => {
  switch regime {
  | "unknown" => Offline
  | _ => Online
  }
}

@react.component
let make = () => {
  let apiState = ApiHooks.useDashboard()
  let data = switch apiState {
  | ApiHooks.Loading => Loading
  | ApiHooks.Failed({message}) => FailedToLoad({reason: message})
  | ApiHooks.Loaded(resp) =>
    Loaded({
      totalPnl: Position.Pnl(resp.totalPnl),
      activePositions: resp.activePositions,
      botStatus: regimeToStatus(resp.regime),
    })
  }

  <div className="spqr-section-gap">
    <SectionHeader title="Dashboard" icon="layout-dashboard" />
    {switch data {
    | Loading =>
      <LiftKit.Card variant=#outline>
        <LiftKit.Text fontClass=#body color=#onsurfacevariant>
          {React.string("Loading dashboard...")}
        </LiftKit.Text>
      </LiftKit.Card>
    | FailedToLoad({reason}) =>
      <LiftKit.Card variant=#outline bgColor=#errorcontainer>
        <LiftKit.Text fontClass=#body color=#onerrorcontainer>
          {React.string(`Failed to load: ${reason}`)}
        </LiftKit.Text>
      </LiftKit.Card>
    | Loaded({totalPnl, activePositions, botStatus}) =>
      let Position.Pnl(pnlValue) = totalPnl
      let pnlColor = pnlValue >= 0.0 ? #primary : #error
      <LiftKit.Grid columns=3 gap=#md autoResponsive=true>
        <MetricCard
          label="Total P&L"
          value={`$${pnlValue->Float.toString}`}
          fontColor=pnlColor
        />
        <MetricCard
          label="Active Positions"
          value={activePositions->Int.toString}
        />
        <MetricCard label="Bot Status">
          <LiftKit.Row alignItems=#center gap=#"2xs">
            <span className={botStatus->botStatusDotClass} />
            <LiftKit.Heading tag=#h3 fontClass=#"title1-bold" fontColor={botStatus->botStatusColor}>
              {React.string(botStatus->botStatusToString)}
            </LiftKit.Heading>
          </LiftKit.Row>
        </MetricCard>
      </LiftKit.Grid>
    }}
  </div>
}
