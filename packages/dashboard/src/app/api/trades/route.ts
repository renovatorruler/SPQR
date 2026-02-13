// GET /api/trades — paginated trade history
//
// Query params:
//   limit  — max results (default 100, max 1000)
//   offset — skip N results (default 0)
//
// Returns: { trades: TradeData[], total: number }

import { NextResponse } from "next/server";
import { getTrades, isDbAvailable } from "@/lib/db-reader";

export async function GET(request: Request) {
  if (!isDbAvailable()) {
    return NextResponse.json({ trades: [], total: 0 });
  }

  try {
    const { searchParams } = new URL(request.url);
    const limit = Math.min(
      Math.max(parseInt(searchParams.get("limit") ?? "100", 10) || 100, 1),
      1000
    );
    const offset = Math.max(
      parseInt(searchParams.get("offset") ?? "0", 10) || 0,
      0
    );

    const trades = getTrades(limit, offset);
    return NextResponse.json({ trades });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return NextResponse.json(
      { error: `Database read failed: ${message}` },
      { status: 500 }
    );
  }
}
