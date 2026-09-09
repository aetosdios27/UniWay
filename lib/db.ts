import postgres from "postgres";
import singletonLogger from "@/lib/logger";

const connectionString = process.env.DATABASE_URL;
const STATEMENT_TIMEOUT_MS = parseInt(process.env.DATABASE_STATEMENT_TIMEOUT || "", 10) || 30_000;
// Neon free/launch-tier computes scale to zero after idle (see .agents/skills/neon-postgres/SKILL.md).
// The connection pool is per-instance, so keep this modest by default — raising it blindly on a
// serverless deployment multiplies by however many function instances are warm, and can exhaust
// Neon's direct (non-pooled) connection cap. Override only if you've confirmed headroom for it.
const POOL_MAX = parseInt(process.env.DATABASE_POOL_MAX || "", 10) || 10;
const IDLE_TIMEOUT_S = parseInt(process.env.DATABASE_IDLE_TIMEOUT || "", 10) || 20;

if (!connectionString) {
  singletonLogger.warn("DATABASE_URL is not set. Database queries will fail at runtime.");
}

if (connectionString && process.env.NODE_ENV === "production" && !new URL(connectionString).hostname.includes("-pooler")) {
  // Neon serves pooled (PgBouncer) connections from a "-pooler" endpoint. Without it, each warm
  // serverless instance's pool counts against Neon's much smaller direct-connection limit, so a
  // burst of concurrent instances can exhaust it outright (see Connection Pooling in the Neon skill).
  singletonLogger.warn("DATABASE_URL does not target a Neon pooled (-pooler) endpoint; concurrent traffic may exhaust direct connections.");
}

const ssl = connectionString
  ? (new URL(connectionString).searchParams.get("sslmode") === "require" ? "require" as const : false)
  : "require" as const;

// Ensure a single connection pool in development
const globalForPostgres = globalThis as unknown as {
  sql: postgres.Sql | undefined;
};

const rawSql: postgres.Sql =
  globalForPostgres.sql ??
  postgres(connectionString || "postgres://dummy:dummy@localhost/dummy", {
    max: POOL_MAX,
    idle_timeout: IDLE_TIMEOUT_S,
    connect_timeout: 10,
    ssl,
    connection: { statement_timeout: STATEMENT_TIMEOUT_MS },
  });

if (process.env.NODE_ENV !== "production") {
  globalForPostgres.sql = rawSql;
}

// Errors postgres.js raises before a query's bytes ever reach the server — safe to retry
// unconditionally, writes included, because the server never saw the query.
// (CONNECTION_CLOSED/CONNECTION_DESTROYED/CONNECTION_ENDED are deliberately excluded: those can
// fire after a query was already sent, so retrying could double-execute a write.)
const RETRYABLE_CONNECTION_CODES = new Set([
  "CONNECT_TIMEOUT",
  "ECONNREFUSED",
  "ECONNRESET",
  "ETIMEDOUT",
  "EHOSTUNREACH",
  "EAI_AGAIN",
  "ENOTFOUND",
]);
// 5 retries at these bounds bridge Neon's documented "hundreds of ms" scale-to-zero cold start
// (2.3s minimum, ~4.6s worst case, before giving up) without leaving a truly-dead DB hanging long.
const MAX_CONNECTION_RETRIES = 5;
const RETRY_BASE_DELAY_MS = 150;
const RETRY_MAX_DELAY_MS = 3_000;

function isRetryableConnectionError(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error
    && RETRYABLE_CONNECTION_CODES.has(String((error as { code?: unknown }).code));
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Exponential backoff with equal jitter (AWS Builders' Library: "Timeouts, retries, and backoff
// with jitter") smooths over a Neon compute waking from scale-to-zero without a thundering herd of
// synchronized retries if several requests hit the cold start at once. Equal jitter (half fixed,
// half random) is used over full jitter so the delay floor still grows with each attempt instead
// of occasionally rounding to ~0 — full jitter can otherwise burn through the retry budget in a
// few milliseconds and give up before a real cold start has had any chance to finish.
async function withConnectionRetry<T>(run: (attempt: number) => Promise<T>, attempt = 0): Promise<T> {
  try {
    return await run(attempt);
  } catch (error) {
    if (attempt >= MAX_CONNECTION_RETRIES || !isRetryableConnectionError(error)) throw error;
    const backoff = Math.min(RETRY_MAX_DELAY_MS, RETRY_BASE_DELAY_MS * 2 ** attempt);
    const delayMs = backoff / 2 + Math.random() * (backoff / 2);
    singletonLogger.warn("retrying query after connection error", {
      code: (error as { code?: unknown }).code,
      attempt: attempt + 1,
      delayMs: Math.round(delayMs),
    });
    await sleep(delayMs);
    return withConnectionRetry(run, attempt + 1);
  }
}

// postgres.js's `sql\`...\`` returns a `Query`, which extends Promise but stays inert (`.executed
// === false`) until something actually calls `.then()`/`.catch()`/`.finally()`/`.execute()` on it.
// That laziness is load-bearing: this codebase composes queries by passing an unexecuted Query as
// a fragment into another query (e.g. `rooms.ts`'s `buildingFilter`), and postgres.js recognizes
// fragments via `instanceof Query` — see node_modules/postgres/src/types.js. An earlier bug broke
// exactly this (see git log "fix: preserve native Postgres query composition"), so retrying by
// eagerly awaiting every call (turning it into a plain Promise) is off the table: it would execute
// fragments that are never meant to run standalone, and strip the shape composition depends on.
// Instead, only `.then` is intercepted — the sole method `await` ever calls — so a query used as a
// fragment is completely untouched, while a query that's actually awaited retries transparently.
// `sql.begin`, `.unsafe`, `.reserved`, etc. aren't tagged-template calls and pass straight through
// via the default `get` trap below, so transaction semantics (and the statement-cancellation
// behavior scripts/.stress-boundaries.ts exercises) are unaffected.
type LazyQuery = PromiseLike<unknown> & { then: (...a: unknown[]) => unknown };

export const sql: postgres.Sql = new Proxy(rawSql, {
  apply(target, thisArg, args) {
    const query = Reflect.apply(target as (...a: unknown[]) => unknown, thisArg, args);
    if (!query || typeof (query as { then?: unknown }).then !== "function") return query;

    return new Proxy(query as LazyQuery, {
      get(queryTarget, prop, receiver) {
        if (prop !== "then") return Reflect.get(queryTarget, prop, receiver);
        return (onFulfilled?: (v: unknown) => unknown, onRejected?: (e: unknown) => unknown) =>
          withConnectionRetry((attempt) =>
            Promise.resolve(attempt === 0 ? queryTarget : Reflect.apply(target as (...a: unknown[]) => unknown, thisArg, args))
          ).then(onFulfilled, onRejected);
      },
    });
  },
}) as postgres.Sql;

// Graceful shutdown — close DB connections on process exit
/* v8 ignore start */
const SHUTDOWN_TIMEOUT_MS = 5_000;

function shutdown(signal: string) {
  singletonLogger.info("shutting down database connections", { signal });
  const timeout = setTimeout(() => {
    singletonLogger.warn("database shutdown timed out, forcing exit");
    process.exit(1);
  }, SHUTDOWN_TIMEOUT_MS);
  timeout.unref();

  sql.end().then(() => {
    clearTimeout(timeout);
    singletonLogger.info("database connections closed", { signal });
  });
}

if (typeof process !== "undefined" && !process.env.VITEST) {
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}
/* v8 ignore stop */
