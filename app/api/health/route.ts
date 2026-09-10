import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { createLogger } from "@/lib/logger";

export const dynamic = "force-dynamic";

// Hit this before a demo to pre-warm a suspended Neon compute on purpose: the request rides
// lib/db.ts's own connection retry, so it blocks (up to ~4.6s) until the DB actually answers
// instead of failing on the first cold-start hiccup — turning "is the DB awake?" into a single
// GET instead of guessing from the first real user request.
export async function GET(request: Request) {
  const start = performance.now();
  try {
    await sql`SELECT 1`;
    return NextResponse.json(
      { status: "ok", db: "up", latencyMs: Math.round(performance.now() - start) },
      { headers: { "Cache-Control": "no-store" } }
    );
  } catch (error) {
    const requestId = request.headers.get("x-request-id") ?? crypto.randomUUID();
    createLogger(requestId).error("Health check failed: database unreachable", { error: String(error) });
    // This is a public, unauthenticated endpoint — don't hand back connection details or
    // hostnames from the raw error. Full detail goes to the server log above instead.
    return NextResponse.json(
      {
        status: "degraded",
        db: "down",
        error: process.env.NODE_ENV === "production" ? "Database unreachable" : String(error),
        requestId,
      },
      { status: 503, headers: { "Cache-Control": "no-store", "X-Request-Id": requestId } }
    );
  }
}
