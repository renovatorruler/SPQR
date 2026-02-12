// Root application component — LiftKit styled

@react.component
let make = () => {
  let sampleTrades: array<Trade.trade> = []
  let backtestTrades: array<Trade.trade> = [
    {
      Trade.id: Trade.TradeId("bt-1"),
      symbol: Trade.Symbol("BTCUSD"),
      side: Trade.Buy,
      orderType: Trade.Market,
      requestedQty: Trade.Quantity(0.1),
      status: Trade.Filled({
        filledAt: Trade.Timestamp(Date.now()),
        filledPrice: Trade.Price(42000.0),
      }),
      createdAt: Trade.Timestamp(Date.now()),
    },
  ]

  let backtestResult: Backtest.result = {
    trades: backtestTrades,
    equityCurve: [
      {Backtest.time: Trade.Timestamp(0.0), balance: Config.Balance(10000.0)},
      {Backtest.time: Trade.Timestamp(1.0), balance: Config.Balance(10150.0)},
    ],
    metrics: {
      totalTrades: Backtest.TradeCount(12),
      winRate: Backtest.WinRate(0.58),
      totalReturn: Backtest.ReturnPercent(15.3),
      maxDrawdown: Backtest.DrawdownPercent(6.7),
    },
  }

  let qflConfig: Config.qflConfig = {
    crackThreshold: Config.CrackPercent(3.0),
    baseFilter: {
      minBounces: Config.BounceCount(2),
      tolerance: Config.TolerancePercent(0.5),
      maxBaseDrift: Config.DriftPercent(1.0),
    },
    exitPolicy: {
      stopLoss: Config.StopLossPercent(5.0),
      takeProfit: Config.TakeProfitPercent(2.0),
      maxHold: Config.HoldCandles(16),
    },
    reentry: Config.ReentryOnce({cooldown: Config.CooldownCandles(32)}),
    regimeGate: {
      emaFast: Config.EmaPeriod(50),
      emaSlow: Config.EmaPeriod(200),
      emaSlopeLookback: Config.EmaSlopeLookback(20),
    },
    setupEvaluation: Config.Committee({
      members: [],
      rule: Config.SimpleMajority,
      minConfidence: Config.Confidence(0.6),
    }),
    lookbackCandles: Config.CandleCount(200),
  }

  <LiftKit.Container maxWidth="lg">
    <LiftKit.Section py="md" px="sm">
      // Header
      <div className="spqr-header">
        <LiftKit.Row alignItems="center" justifyContent="space-between" gap="md" wrapChildren=true>
          <LiftKit.Heading tag="h1" fontClass="display2-bold">
            {React.string("SPQR Trading Bot")}
          </LiftKit.Heading>
          <LiftKit.Badge icon="activity" color="primary" scale="md" />
        </LiftKit.Row>
      </div>
      // Main content
      <div className="spqr-section-gap mt-lg">
        <Dashboard />
        <BacktestSummary metrics={backtestResult.metrics} />
        <BacktestEquityCurve equity={backtestResult.equityCurve} />
        <LiftKit.Grid columns=2 gap="md" autoResponsive=true>
          <StrategyConfigPanel config=qflConfig />
          <BacktestTrades trades={backtestResult.trades} />
        </LiftKit.Grid>
        <TradeHistory trades=sampleTrades />
      </div>
    </LiftKit.Section>
  </LiftKit.Container>
}
