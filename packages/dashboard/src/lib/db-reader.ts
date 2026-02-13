// Read-only SQLite reader for dashboard API routes
//
// Opens the bot's database in read-only mode with query_only pragma
// to prevent accidental writes from the dashboard process.
//
// The database path is configured via SPQR_DB_PATH environment variable,
// defaulting to "spqr_bot.db" (relative to process CWD).

import Database from "better-sqlite3";
import path from "path";

const DB_PATH = process.env.SPQR_DB_PATH ?? "spqr_bot.db";

// Lazy singleton — opened on first query, reused across requests
let _db: Database.Database | null = null;

function getDb(): Database.Database {
  if (!_db) {
    const resolvedPath = path.resolve(DB_PATH);
    _db = new Database(resolvedPath, { readonly: true });
    _db.pragma("journal_mode = WAL");
    _db.pragma("query_only = ON");
  }
  return _db;
}

// --- Row types matching the SQLite schema ---

interface TradeRow {
  id: string;
  symbol: string;
  side: string;
  order_type: string;
  requested_qty: number;
  status: string;
  filled_price: number | null;
  filled_at: number | null;
  created_at: number;
}

interface PositionRow {
  symbol: string;
  side: string;
  entry_price: number;
  current_qty: number;
  status: string;
  opened_at: number;
  closed_at: number | null;
  realized_pnl: number | null;
}

interface StateRow {
  key: string;
  value: string;
  updated_at: number;
}

// --- API response types ---

export interface DashboardData {
  totalPnl: number;
  activePositions: number;
  regime: string;
  lastUpdated: number | null;
}

export interface TradeData {
  id: string;
  symbol: string;
  side: "buy" | "sell";
  orderType: "market" | "limit";
  requestedQty: number;
  status: string;
  filledPrice: number | null;
  filledAt: number | null;
  createdAt: number;
}

// --- Queries ---

export function getDashboardData(): DashboardData {
  const db = getDb();

  // Total realized PnL from closed positions
  const pnlRow = db
    .prepare(
      "SELECT COALESCE(SUM(realized_pnl), 0) as total_pnl FROM positions WHERE status = 'closed'"
    )
    .get() as { total_pnl: number } | undefined;
  const totalPnl = pnlRow?.total_pnl ?? 0;

  // Count open positions
  const countRow = db
    .prepare("SELECT COUNT(*) as count FROM positions WHERE status = 'open'")
    .get() as { count: number } | undefined;
  const activePositions = countRow?.count ?? 0;

  // Market regime from bot_state
  const stateRow = db
    .prepare("SELECT value, updated_at FROM bot_state WHERE key = 'regime'")
    .get() as StateRow | undefined;
  const regime = stateRow?.value ?? "unknown";
  const lastUpdated = stateRow?.updated_at ?? null;

  return { totalPnl, activePositions, regime, lastUpdated };
}

export function getTrades(limit: number = 100, offset: number = 0): TradeData[] {
  const db = getDb();

  const rows = db
    .prepare(
      "SELECT * FROM trades ORDER BY created_at DESC LIMIT ? OFFSET ?"
    )
    .all(limit, offset) as TradeRow[];

  return rows.map((row) => ({
    id: row.id,
    symbol: row.symbol,
    side: row.side as "buy" | "sell",
    orderType: row.order_type as "market" | "limit",
    requestedQty: row.requested_qty,
    status: row.status,
    filledPrice: row.filled_price,
    filledAt: row.filled_at,
    createdAt: row.created_at,
  }));
}

// Check if the database file exists and is readable
export function isDbAvailable(): boolean {
  try {
    getDb();
    return true;
  } catch {
    return false;
  }
}
