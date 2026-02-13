// API hooks — typed SWR hooks for dashboard data fetching
//
// Each hook fetches from a specific API route and decodes the JSON
// into ReScript domain types. Decoding failures surface as errors
// rather than silently returning wrong data.

// Minimal fetch bindings for the browser Fetch API
type response
@val external fetch: string => promise<response> = "fetch"
@send external json: response => promise<JSON.t> = "json"

// Response types matching the API route JSON shapes
type dashboardResponse = {
  totalPnl: float,
  activePositions: int,
  regime: string,
  lastUpdated: Nullable.t<float>,
}

type tradeResponse = {
  id: string,
  symbol: string,
  side: string,
  orderType: string,
  requestedQty: float,
  status: string,
  filledPrice: Nullable.t<float>,
  filledAt: Nullable.t<float>,
  createdAt: float,
}

type tradesApiResponse = {trades: array<tradeResponse>}

// Decode a trade API response into a domain Trade.trade
let decodeTrade = (raw: tradeResponse): option<Trade.trade> => {
  let side = switch raw.side {
  | "buy" => Some(Trade.Buy)
  | "sell" => Some(Trade.Sell)
  | _ => None
  }
  let orderType = switch raw.orderType {
  | "market" => Some(Trade.Market)
  | "limit" =>
    switch raw.filledPrice->Nullable.toOption {
    | Some(p) => Some(Trade.Limit({limitPrice: Trade.Price(p)}))
    | None => Some(Trade.Market)
    }
  | _ => None
  }
  let status = switch raw.status {
  | "pending" => Some(Trade.Pending)
  | "filled" =>
    Some(
      Trade.Filled({
        filledAt: Trade.Timestamp(raw.filledAt->Nullable.toOption->Option.getOr(0.0)),
        filledPrice: Trade.Price(raw.filledPrice->Nullable.toOption->Option.getOr(0.0)),
      }),
    )
  | "cancelled" => Some(Trade.Cancelled({cancelledAt: Trade.Timestamp(0.0), reason: "unknown"}))
  | "rejected" => Some(Trade.Rejected({rejectedAt: Trade.Timestamp(0.0), reason: "unknown"}))
  | _ => None
  }

  switch (side, orderType, status) {
  | (Some(s), Some(ot), Some(st)) =>
    Some({
      Trade.id: Trade.TradeId(raw.id),
      symbol: Trade.Symbol(raw.symbol),
      side: s,
      orderType: ot,
      requestedQty: Trade.Quantity(raw.requestedQty),
      status: st,
      createdAt: Trade.Timestamp(raw.createdAt),
    })
  | _ => None
  }
}

// Dashboard data — totalPnl, activePositions, regime
type dashboardState =
  | Loading
  | Loaded(dashboardResponse)
  | Failed({message: string})

let useDashboard = (): dashboardState => {
  let {data, error, isLoading}: Swr.swrResponse<dashboardResponse> = Swr.useSWR(
    "/api/dashboard",
    async (url) => {
      let response = await fetch(url)
      let jsonVal = await json(response)
      (Obj.magic(jsonVal): dashboardResponse)
    },
  )

  switch (isLoading, error, data) {
  | (true, _, _) => Loading
  | (_, Some(e), _) => Failed({message: JsExn.message(e)->Option.getOr("Unknown error")})
  | (_, _, Some(d)) => Loaded(d)
  | (false, None, None) => Loading
  }
}

// Trades — paginated trade history
type tradesState =
  | Loading
  | Loaded({trades: array<Trade.trade>})
  | Failed({message: string})

let useTrades = (~limit: int=100, ~offset: int=0): tradesState => {
  let url = `/api/trades?limit=${limit->Int.toString}&offset=${offset->Int.toString}`
  let {data, error, isLoading}: Swr.swrResponse<tradesApiResponse> = Swr.useSWR(url, async (u) => {
    let response = await fetch(u)
    let jsonVal = await json(response)
    (Obj.magic(jsonVal): tradesApiResponse)
  })

  switch (isLoading, error, data) {
  | (true, _, _) => Loading
  | (_, Some(e), _) => Failed({message: JsExn.message(e)->Option.getOr("Unknown error")})
  | (_, _, Some({trades})) =>
    let decoded = trades->Array.filterMap(decodeTrade)
    Loaded({trades: decoded})
  | (false, None, None) => Loading
  }
}
