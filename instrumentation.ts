import * as Sentry from "@sentry/nextjs";

export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    await import("./sentry.server.config");
    // Fire-and-forget: starts warming the Postgres pool (and, on Neon, nudges a suspended
    // compute awake) the moment this instance boots, instead of making the first real request
    // pay for it. Deliberately not awaited — a slow cold start here would otherwise delay this
    // instance from accepting any requests at all. Failures are swallowed: lib/db.ts's own
    // connection retry covers the real request if this doesn't finish first.
    // Skipped during `next build` and when DATABASE_URL isn't set (e.g. CI without a DB) — there's
    // no server about to accept requests yet, so there's nothing to warm ahead of, and it would
    // otherwise burn through the full connection-retry budget against build-time/dummy credentials.
    if (process.env.DATABASE_URL && process.env.NEXT_PHASE !== "phase-production-build") {
      import("@/lib/db")
        .then(({ sql }) => sql`SELECT 1`)
        .catch(() => {});
    }
  }

  if (process.env.NEXT_RUNTIME === "edge") {
    await import("./sentry.edge.config");
  }
}

export const onRequestError = Sentry.captureRequestError;
