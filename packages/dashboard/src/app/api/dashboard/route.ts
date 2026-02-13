// GET /api/dashboard — aggregated bot status for the Dashboard component
//
// Returns: { totalPnl, activePositions, regime, lastUpdated }
// Falls back to defaults when the database is unavailable (bot not yet run).

import { NextResponse } from "next/server";
import { getDashboardData, isDbAvailable } from "@/lib/db-reader";

export async function GET() {
  if (!isDbAvailable()) {
    return NextResponse.json({
      totalPnl: 0,
      activePositions: 0,
      regime: "unknown",
      lastUpdated: null,
    });
  }

  try {
    const data = getDashboardData();
    return NextResponse.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return NextResponse.json(
      { error: `Database read failed: ${message}` },
      { status: 500 }
    );
  }
}
