// Backtest runner — deterministic single-symbol simulation

let applySlippage = (
  ~price: Trade.price,
  ~side: Trade.side,
  ~model: Backtest.slippageModel,
): Trade.price => {
  let Trade.Price(p) = price
  switch model {
  | Backtest.NoSlippage => price
  | Backtest.FixedBps({bps}) =>
    let Backtest.BasisPoints(bp) = bps
    let factor = bp /. 10000.0
    switch side {
    | Trade.Buy => Trade.Price(p *. (1.0 +. factor))
    | Trade.Sell => Trade.Price(p *. (1.0 -. factor))
    }
  }
}

let applyFee = (~amount: float, ~model: Backtest.feeModel): float => {
  switch model {
  | Backtest.NoFees => amount
  | Backtest.FixedBps({bps}) =>
    let Backtest.BasisPoints(bp) = bps
    let fee = amount *. (bp /. 10000.0)
    amount -. fee
  }
}

type openState = {
  position: Position.position,
  base: BaseDetector.base,
  openedIndex: int,
}

type reentryState = {
  used: bool,
  cooldownUntil: option<int>,
  lastBase: option<Trade.price>,
}

type state = {
  balance: Config.balance,
  equity: array<Backtest.equityPoint>,
  trades: array<Trade.trade>,
  pnls: array<Position.pnl>,
  openPosition: option<openState>,
  reentry: reentryState,
}

let canEnter = (~reentry: reentryState, ~index: int, ~base: BaseDetector.base): bool => {
  let cooldownActive = switch reentry.cooldownUntil {
  | Some(untilIndex) => index < untilIndex
  | None => false
  }

  let sameBase = switch reentry.lastBase {
  | Some(lastBase) =>
    let Trade.Price(last) = lastBase
    let Trade.Price(current) = base.priceLevel
    last == current
  | None => false
  }

  !cooldownActive && (!reentry.used || !sameBase)
}

let updateEquity = (
  ~equity: array<Backtest.equityPoint>,
  ~time: Trade.timestamp,
  ~balance: Config.balance,
  ~openPosition: option<openState>,
  ~currentPrice: Trade.price,
): array<Backtest.equityPoint> => {
  let Config.Balance(cash) = balance
  let equityValue = switch openPosition {
  | None => cash
  | Some({position}) =>
    let Position.Pnl(pnl) = Position.unrealizedPnl(position, currentPrice)
    cash +. pnl
  }
  equity->Array.concat([{Backtest.time: time, balance: Config.Balance(equityValue)}])
}

let makeTrade = (
  ~id: string,
  ~symbol: Trade.symbol,
  ~side: Trade.side,
  ~qty: Trade.quantity,
  ~price: Trade.price,
  ~time: Trade.timestamp,
): Trade.trade => {
  let trade =
    Trade.make(
      ~id=Trade.TradeId(id),
      ~symbol,
      ~side,
      ~orderType=Trade.Market,
      ~requestedQty=qty,
      ~createdAt=time,
    )
  {...trade, status: Filled({filledAt: time, filledPrice: price})}
}

let runSingleSymbol = (
  ~symbol: Trade.symbol,
  ~candles: array<Config.candlestick>,
  ~config: Backtest.backtestConfig,
  ~qfl: Config.qflConfig,
): result<Backtest.result, BotError.t> => {
  let Config.CandleCount(lookback) = qfl.lookbackCandles

  if candles->Array.length < lookback {
    Error(BotError.StrategyError(InsufficientData({required: lookback, available: candles->Array.length})))
  } else {
    let initial = config.initialBalance
    let initialState: state = {
      balance: initial,
      equity: [],
      trades: [],
      pnls: [],
      openPosition: None,
      reentry: {used: false, cooldownUntil: None, lastBase: None},
    }

    let indexed = candles->Array.mapWithIndex((c, i) => (c, i))

    let finalState = indexed->Array.reduce(initialState, (st, (candle, i)) => {
      let currentPrice = candle.close
      let now = candle.closeTime
      let windowStart = i - (lookback - 1)
      let window =
        switch windowStart >= 0 {
        | true => candles->Array.slice(~start=windowStart, ~end=i + 1)
        | false => []
        }

      let maxHold = qfl.exitPolicy.maxHold
      let Config.HoldCandles(maxHoldCandles) = maxHold
      let timeStop = switch st.openPosition {
      | Some(openPos) => (i - openPos.openedIndex) >= maxHoldCandles
      | None => false
      }

      let openInfo: option<QflStrategy.openPositionInfo> =
        st.openPosition->Option.map(op => {
          let record: QflStrategy.openPositionInfo = {
            QflStrategy.entryPrice: op.position.entryPrice,
            base: op.base,
          }
          record
        })

      let signal =
        if window->Array.length == 0 {
          Ok(QflStrategy.NoSignal)
        } else {
          QflStrategy.analyze(
            ~candles=window,
            ~currentPrice,
            ~symbol,
            ~config=qfl,
            ~openPosition=openInfo,
          )
        }

      let (nextState, didExit) =
        switch (signal, st.openPosition, timeStop) {
        | (_, Some(openPos), true) =>
          let exitPrice = applySlippage(~price=currentPrice, ~side=Trade.Sell, ~model=config.slippageModel)
          let Trade.Price(exitPriceVal) = exitPrice
          let Trade.Quantity(qty) = openPos.position.currentQty
          let gross = exitPriceVal *. qty
          let net = applyFee(~amount=gross, ~model=config.feeModel)
          let Config.Balance(cash) = st.balance
          let newBalance = Config.Balance(cash +. net)
          let pnl = Position.computePnl(
            ~side=Position.Long,
            ~entryPrice=openPos.position.entryPrice,
            ~currentPrice=exitPrice,
            ~qty=openPos.position.currentQty,
          )
          let trade = makeTrade(
            ~id=`bt-${i->Int.toString}-exit`,
            ~symbol,
            ~side=Trade.Sell,
            ~qty=openPos.position.currentQty,
            ~price=exitPrice,
            ~time=now,
          )
          ({
            ...st,
            balance: newBalance,
            trades: st.trades->Array.concat([trade]),
            pnls: st.pnls->Array.concat([pnl]),
            openPosition: None,
            reentry: {
              used: true,
              cooldownUntil: switch qfl.reentry {
              | Config.ReentryOnce({cooldown: Config.CooldownCandles(c)}) => Some(i + c)
              | Config.NoReentry => None
              },
              lastBase: Some(openPos.base.priceLevel),
            },
          }, true)

        | (Ok(QflStrategy.BounceBack(_)), Some(openPos), _) =>
          let exitPrice = applySlippage(~price=currentPrice, ~side=Trade.Sell, ~model=config.slippageModel)
          let Trade.Price(exitPriceVal) = exitPrice
          let Trade.Quantity(qty) = openPos.position.currentQty
          let gross = exitPriceVal *. qty
          let net = applyFee(~amount=gross, ~model=config.feeModel)
          let Config.Balance(cash) = st.balance
          let newBalance = Config.Balance(cash +. net)
          let pnl = Position.computePnl(
            ~side=Position.Long,
            ~entryPrice=openPos.position.entryPrice,
            ~currentPrice=exitPrice,
            ~qty=openPos.position.currentQty,
          )
          let trade = makeTrade(
            ~id=`bt-${i->Int.toString}-exit`,
            ~symbol,
            ~side=Trade.Sell,
            ~qty=openPos.position.currentQty,
            ~price=exitPrice,
            ~time=now,
          )
          ({
            ...st,
            balance: newBalance,
            trades: st.trades->Array.concat([trade]),
            pnls: st.pnls->Array.concat([pnl]),
            openPosition: None,
            reentry: {...st.reentry, used: false},
          }, true)

        | (Ok(QflStrategy.StopLossTriggered(_)), Some(openPos), _) =>
          let exitPrice = applySlippage(~price=currentPrice, ~side=Trade.Sell, ~model=config.slippageModel)
          let Trade.Price(exitPriceVal) = exitPrice
          let Trade.Quantity(qty) = openPos.position.currentQty
          let gross = exitPriceVal *. qty
          let net = applyFee(~amount=gross, ~model=config.feeModel)
          let Config.Balance(cash) = st.balance
          let newBalance = Config.Balance(cash +. net)
          let pnl = Position.computePnl(
            ~side=Position.Long,
            ~entryPrice=openPos.position.entryPrice,
            ~currentPrice=exitPrice,
            ~qty=openPos.position.currentQty,
          )
          let trade = makeTrade(
            ~id=`bt-${i->Int.toString}-exit`,
            ~symbol,
            ~side=Trade.Sell,
            ~qty=openPos.position.currentQty,
            ~price=exitPrice,
            ~time=now,
          )
          ({
            ...st,
            balance: newBalance,
            trades: st.trades->Array.concat([trade]),
            pnls: st.pnls->Array.concat([pnl]),
            openPosition: None,
            reentry: {
              used: true,
              cooldownUntil: switch qfl.reentry {
              | Config.ReentryOnce({cooldown: Config.CooldownCandles(c)}) => Some(i + c)
              | Config.NoReentry => None
              },
              lastBase: Some(openPos.base.priceLevel),
            },
          }, true)

        | _ => (st, false)
        }

      let nextState =
        if didExit {
          nextState
        } else {
          switch (signal, nextState.openPosition) {
          | (Ok(QflStrategy.CrackDetected({base, _})), None) =>
            switch canEnter(~reentry=nextState.reentry, ~index=i, ~base) {
            | false => nextState
            | true =>
              let entryPrice = applySlippage(~price=currentPrice, ~side=Trade.Buy, ~model=config.slippageModel)
              let Trade.Price(entryVal) = entryPrice
              let Config.Balance(cash) = nextState.balance
              let qty = if entryVal > 0.0 { cash /. entryVal } else { 0.0 }
              let qtyT = Trade.Quantity(qty)
              let grossCost = entryVal *. qty
              let netCost = applyFee(~amount=grossCost, ~model=config.feeModel)
              let newBalance = Config.Balance(cash -. netCost)
              let trade = makeTrade(
                ~id=`bt-${i->Int.toString}-entry`,
                ~symbol,
                ~side=Trade.Buy,
                ~qty=qtyT,
                ~price=entryPrice,
                ~time=now,
              )
              let position = Position.make(
                ~symbol,
                ~side=Position.Long,
                ~entryPrice=entryPrice,
                ~qty=qtyT,
                ~openedAt=now,
              )
              {
                ...nextState,
                balance: newBalance,
                trades: nextState.trades->Array.concat([trade]),
                openPosition: Some({position, base, openedIndex: i}),
                reentry: {...nextState.reentry, lastBase: Some(base.priceLevel)},
              }
            }
          | _ => nextState
          }
        }

      {
        ...nextState,
        equity: updateEquity(
          ~equity=nextState.equity,
          ~time=now,
          ~balance=nextState.balance,
          ~openPosition=nextState.openPosition,
          ~currentPrice,
        ),
      }
    })

    let metrics = BacktestMetrics.computeMetrics(
      ~initialBalance=initial,
      ~equity=finalState.equity,
      ~pnls=finalState.pnls,
    )

    Ok({
      trades: finalState.trades,
      equityCurve: finalState.equity,
      metrics,
    })
  }
}
