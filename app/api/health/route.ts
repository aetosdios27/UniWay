import { NextResponse } from "next/server";
import { sql } from "@/lib/db";

export const dynamic = "force-dynamic";

// Hit this before a demo to pre-warm a suspended Neon compute on purpose: the request rides
// lib/db.ts's own connection retry, so it blocks (up to ~4.6s) until the DB actually answers
// instead of failing on the first cold-start hiccup — turning "is the DB awake?" into a single
// GET instead of guessing from the first real user request.
export async function GET() {
  const start = performance.now();
  try {
    await sql`SELECT 1`;
    return NextResponse.json(
      { status: "ok", db: "up", latencyMs: Math.round(performance.now() - start) },
      { headers: { "Cache-Control": "no-store" } }
    );
  } catch (error) {
    return NextResponse.json(
      { status: "degraded", db: "down", error: String(error) },
      { status: 503, headers: { "Cache-Control": "no-store" } }
    );
  }
}
