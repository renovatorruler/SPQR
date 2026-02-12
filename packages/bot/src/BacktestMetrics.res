// Backtest metrics computation

let computeMaxDrawdown = (equity: array<Backtest.equityPoint>): Backtest.drawdownPercent => {
  let (_, _, maxDd) = equity->Array.reduce((0.0, 0.0, 0.0), ((peak, _current, maxDrawdown), point) => {
    let Config.Balance(balance) = point.balance
    let nextPeak = if balance > peak { balance } else { peak }
    let drawdown = if nextPeak > 0.0 { (nextPeak -. balance) /. nextPeak } else { 0.0 }
    let nextMax = if drawdown > maxDrawdown { drawdown } else { maxDrawdown }
    (nextPeak, balance, nextMax)
  })
  Backtest.DrawdownPercent(maxDd *. 100.0)
}

let computeMetrics = (
  ~initialBalance: Config.balance,
  ~equity: array<Backtest.equityPoint>,
  ~pnls: array<Position.pnl>,
): Backtest.metrics => {
  let totalTrades = pnls->Array.length
  let wins = pnls->Array.reduce(0, (acc, pnl) => {
    let Position.Pnl(p) = pnl
    if p > 0.0 { acc + 1 } else { acc }
  })
  let winRate = switch totalTrades {
  | 0 => Backtest.WinRate(0.0)
  | _ => Backtest.WinRate(Float.fromInt(wins) /. Float.fromInt(totalTrades))
  }

  let Config.Balance(initial) = initialBalance
  let lastBalance = switch equity->Array.get(equity->Array.length - 1) {
  | Some(point) => point.balance
  | None => initialBalance
  }
  let Config.Balance(finalBalance) = lastBalance
  let totalReturn = if initial > 0.0 {
    Backtest.ReturnPercent(((finalBalance -. initial) /. initial) *. 100.0)
  } else {
    Backtest.ReturnPercent(0.0)
  }

  {
    totalTrades: Backtest.TradeCount(totalTrades),
    winRate,
    totalReturn,
    maxDrawdown: computeMaxDrawdown(equity),
  }
}
