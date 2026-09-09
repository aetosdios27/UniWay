import postgres from "postgres";
import singletonLogger from "@/lib/logger";

const connectionString = process.env.DATABASE_URL;
const STATEMENT_TIMEOUT_MS = parseInt(process.env.DATABASE_STATEMENT_TIMEOUT || "", 10) || 30_000;

if (!connectionString) {
  singletonLogger.warn("DATABASE_URL is not set. Database queries will fail at runtime.");
}

const ssl = connectionString
  ? (new URL(connectionString).searchParams.get("sslmode") === "require" ? "require" as const : false)
  : "require" as const;

// Ensure a single connection pool in development
const globalForPostgres = globalThis as unknown as {
  sql: postgres.Sql | undefined;
};

export const sql: postgres.Sql =
  globalForPostgres.sql ??
  postgres(connectionString || "postgres://dummy:dummy@localhost/dummy", {
    max: 10,
    idle_timeout: 20,
    connect_timeout: 10,
    ssl,
    connection: { statement_timeout: STATEMENT_TIMEOUT_MS },
  });

if (process.env.NODE_ENV !== "production") {
  globalForPostgres.sql = sql;
}

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
