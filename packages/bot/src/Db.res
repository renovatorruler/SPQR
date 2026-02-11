// SQLite persistence layer using better-sqlite3
// Tables: trades, positions, bot_state, bases
// Uses WAL mode for concurrent reads (dashboard) + writes (bot)
//
// Note: The `exec` calls below are better-sqlite3's Database.exec() for running
// SQL statements, NOT child_process.exec(). This is safe — no shell injection risk.

// better-sqlite3 bindings
type database

@module("better-sqlite3") @new
external openDb: string => database = "default"

@send external pragma: (database, string) => unit = "pragma"
@send external execSql: (database, string) => unit = "exec"
@send external closeDb: database => unit = "close"

type statement
@send external prepare: (database, string) => statement = "prepare"
@send external run: (statement, 'params) => unit = "run"
@send external get: (statement, 'params) => Nullable.t<'row> = "get"
@send external all: (statement, 'params) => array<'row> = "all"

type t = {db: database}

let open_ = (path: string): result<t, BotError.t> => {
  try {
    let db = openDb(path)
    pragma(db, "journal_mode = WAL")
    Ok({db: db})
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(BotError.EngineError(InitializationFailed({message: `SQLite open failed: ${message}`})))
  }
}

let close = (t: t): unit => {
  closeDb(t.db)
}

let migrate = (t: t): result<unit, BotError.t> => {
  try {
    execSql(
      t.db,
      `
      CREATE TABLE IF NOT EXISTS trades (
        id TEXT PRIMARY KEY,
        symbol TEXT NOT NULL,
        side TEXT NOT NULL,
        order_type TEXT NOT NULL,
        requested_qty REAL NOT NULL,
        status TEXT NOT NULL,
        filled_price REAL,
        filled_at REAL,
        created_at REAL NOT NULL
      );

      CREATE TABLE IF NOT EXISTS positions (
        symbol TEXT NOT NULL,
        side TEXT NOT NULL,
        entry_price REAL NOT NULL,
        current_qty REAL NOT NULL,
        status TEXT NOT NULL,
        opened_at REAL NOT NULL,
        closed_at REAL,
        realized_pnl REAL,
        PRIMARY KEY (symbol, opened_at)
      );

      CREATE TABLE IF NOT EXISTS bot_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at REAL NOT NULL
      );

      CREATE TABLE IF NOT EXISTS bases (
        symbol TEXT NOT NULL,
        price_level REAL NOT NULL,
        bounce_count INTEGER NOT NULL,
        first_seen REAL NOT NULL,
        last_bounce REAL NOT NULL,
        PRIMARY KEY (symbol, price_level)
      );

      CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol);
      CREATE INDEX IF NOT EXISTS idx_positions_status ON positions(status);
      CREATE INDEX IF NOT EXISTS idx_bases_symbol ON bases(symbol);
      `,
    )
    Ok()
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(BotError.EngineError(InitializationFailed({message: `Migration failed: ${message}`})))
  }
}

// Trade operations
let insertTrade = (t: t, trade: Trade.trade): result<unit, BotError.t> => {
  try {
    let Trade.TradeId(id) = trade.id
    let Trade.Symbol(symbol) = trade.symbol
    let sideStr = switch trade.side {
    | Trade.Buy => "buy"
    | Trade.Sell => "sell"
    }
    let orderTypeStr = switch trade.orderType {
    | Trade.Market => "market"
    | Trade.Limit(_) => "limit"
    }
    let Trade.Quantity(qty) = trade.requestedQty
    let Trade.Timestamp(createdAt) = trade.createdAt

    let (statusStr, filledPrice, filledAt) = switch trade.status {
    | Trade.Pending => ("pending", Nullable.null, Nullable.null)
    | Trade.Filled({filledPrice, filledAt}) =>
      let Trade.Price(p) = filledPrice
      let Trade.Timestamp(t) = filledAt
      ("filled", Nullable.make(p), Nullable.make(t))
    | Trade.PartiallyFilled(_) => ("partial", Nullable.null, Nullable.null)
    | Trade.Cancelled(_) => ("cancelled", Nullable.null, Nullable.null)
    | Trade.Rejected(_) => ("rejected", Nullable.null, Nullable.null)
    }

    let stmt = prepare(
      t.db,
      "INSERT OR REPLACE INTO trades (id, symbol, side, order_type, requested_qty, status, filled_price, filled_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    run(stmt, (id, symbol, sideStr, orderTypeStr, qty, statusStr, filledPrice, filledAt, createdAt))
    Ok()
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(BotError.EngineError(TickFailed({symbol: "db", message: `Insert trade failed: ${message}`})))
  }
}

// Position operations
let insertPosition = (t: t, pos: Position.position): result<unit, BotError.t> => {
  try {
    let Trade.Symbol(symbol) = pos.symbol
    let sideStr = switch pos.side {
    | Position.Long => "long"
    | Position.Short => "short"
    }
    let Trade.Price(entryPrice) = pos.entryPrice
    let Trade.Quantity(qty) = pos.currentQty

    let (statusStr, openedAt, closedAt, realizedPnl) = switch pos.status {
    | Position.Open({openedAt}) =>
      let Trade.Timestamp(t) = openedAt
      ("open", t, Nullable.null, Nullable.null)
    | Position.Closed({openedAt, closedAt, realizedPnl}) =>
      let Trade.Timestamp(ot) = openedAt
      let Trade.Timestamp(ct) = closedAt
      let Position.Pnl(pnl) = realizedPnl
      ("closed", ot, Nullable.make(ct), Nullable.make(pnl))
    }

    let stmt = prepare(
      t.db,
      "INSERT OR REPLACE INTO positions (symbol, side, entry_price, current_qty, status, opened_at, closed_at, realized_pnl) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    )
    run(
      stmt,
      (symbol, sideStr, entryPrice, qty, statusStr, openedAt, closedAt, realizedPnl),
    )
    Ok()
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(
      BotError.EngineError(
        TickFailed({symbol: "db", message: `Insert position failed: ${message}`}),
      ),
    )
  }
}

let getOpenPositions = (t: t): result<array<Position.position>, BotError.t> => {
  try {
    let stmt = prepare(t.db, "SELECT * FROM positions WHERE status = 'open'")
    let rows: array<{
      "symbol": string,
      "side": string,
      "entry_price": float,
      "current_qty": float,
      "opened_at": float,
    }> = all(stmt, ())

    let positions = rows->Array.filterMap(row => {
      let side = switch row["side"] {
      | "long" => Some(Position.Long)
      | "short" => Some(Position.Short)
      | _ => None
      }
      side->Option.map(s =>
        (
          {
            Position.symbol: Trade.Symbol(row["symbol"]),
            side: s,
            entryPrice: Trade.Price(row["entry_price"]),
            currentQty: Trade.Quantity(row["current_qty"]),
            status: Position.Open({openedAt: Trade.Timestamp(row["opened_at"])}),
          }: Position.position
        )
      )
    })
    Ok(positions)
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(
      BotError.EngineError(
        TickFailed({symbol: "db", message: `Get open positions failed: ${message}`}),
      ),
    )
  }
}

// Base operations
let saveBases = (
  t: t,
  symbol: Trade.symbol,
  bases: array<BaseDetector.base>,
): result<unit, BotError.t> => {
  try {
    let Trade.Symbol(sym) = symbol
    let deleteStmt = prepare(t.db, "DELETE FROM bases WHERE symbol = ?")
    run(deleteStmt, sym)

    let insertStmt = prepare(
      t.db,
      "INSERT INTO bases (symbol, price_level, bounce_count, first_seen, last_bounce) VALUES (?, ?, ?, ?, ?)",
    )
    bases->Array.forEach(base => {
      let Trade.Price(level) = base.priceLevel
      let Config.BounceCount(bounces) = base.bounceCount
      let Trade.Timestamp(firstSeen) = base.firstSeen
      let Trade.Timestamp(lastBounce) = base.lastBounce
      run(insertStmt, (sym, level, bounces, firstSeen, lastBounce))
    })
    Ok()
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(
      BotError.EngineError(TickFailed({symbol: "db", message: `Save bases failed: ${message}`})),
    )
  }
}

let loadBases = (t: t, symbol: Trade.symbol): result<array<BaseDetector.base>, BotError.t> => {
  try {
    let Trade.Symbol(sym) = symbol
    let stmt = prepare(t.db, "SELECT * FROM bases WHERE symbol = ?")
    let rows: array<{
      "price_level": float,
      "bounce_count": int,
      "first_seen": float,
      "last_bounce": float,
    }> = all(stmt, sym)

    let bases = rows->Array.map(row => {
      (
        {
          BaseDetector.priceLevel: Trade.Price(row["price_level"]),
          bounceCount: Config.BounceCount(row["bounce_count"]),
          firstSeen: Trade.Timestamp(row["first_seen"]),
          lastBounce: Trade.Timestamp(row["last_bounce"]),
          minLevel: Trade.Price(row["price_level"]),
          maxLevel: Trade.Price(row["price_level"]),
        }: BaseDetector.base
      )
    })
    Ok(bases)
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(
      BotError.EngineError(TickFailed({symbol: "db", message: `Load bases failed: ${message}`})),
    )
  }
}

// Bot state key-value operations
let saveState = (t: t, key: string, value: string): result<unit, BotError.t> => {
  try {
    let stmt = prepare(
      t.db,
      "INSERT OR REPLACE INTO bot_state (key, value, updated_at) VALUES (?, ?, ?)",
    )
    run(stmt, (key, value, Date.now()))
    Ok()
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(BotError.EngineError(TickFailed({symbol: "db", message: `Save state failed: ${message}`})))
  }
}

let loadState = (t: t, key: string): result<option<string>, BotError.t> => {
  try {
    let stmt = prepare(t.db, "SELECT value FROM bot_state WHERE key = ?")
    let row: Nullable.t<{"value": string}> = get(stmt, key)
    Ok(row->Nullable.toOption->Option.map(r => r["value"]))
  } catch {
  | exn =>
    let message = switch exn {
    | JsExn(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
    | _ => "Unknown error"
    }
    Error(BotError.EngineError(TickFailed({symbol: "db", message: `Load state failed: ${message}`})))
  }
}
