import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

describe("Postgres query contract", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.stubGlobal("sql", undefined);
    vi.stubEnv("DATABASE_URL", "postgres://fake:fake@localhost/fake");
    vi.stubEnv("DATABASE_STATEMENT_TIMEOUT", "5000");
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  it("keeps fragments lazy and retains native query methods", async () => {
    const { sql } = await import("./db");
    const filter = sql`AND id = ${"example"}`;
    const query = sql`SELECT 1 WHERE true ${filter}`;
    expect(filter).toHaveProperty("executed", false);
    expect(query).toHaveProperty("executed", false);
    expect(query.values).toBeTypeOf("function");
    expect(query.cancel).toBeTypeOf("function");
    expect(sql.options.connection.statement_timeout).toBe(5000);
    await sql.end();
  });
});

// Connection-error retry. Mocks the `postgres` factory itself (rather than a real socket) so the
// retry budget can be set to near-zero and every test stays fast and deterministic — the actual
// recovery-through-a-real-cold-start behavior is exercised manually and documented in the PR/commit
// history; this locks in the decision logic (which errors retry, which don't, and the give-up bound).
describe("connection retry", () => {
  function mockPostgresFactory(behavior: (callNumber: number) => unknown) {
    let calls = 0;
    const sqlFn = vi.fn((..._args: unknown[]) => {
      calls += 1;
      return behavior(calls);
    });
    Object.assign(sqlFn, {
      options: { connection: { statement_timeout: 5000 } },
      begin: vi.fn(),
      end: vi.fn().mockResolvedValue(undefined),
      unsafe: vi.fn(),
    });
    return sqlFn;
  }

  function connectionError(code: string) {
    return Object.assign(new Error(`simulated ${code}`), { code });
  }

  beforeEach(() => {
    vi.resetModules();
    vi.stubGlobal("sql", undefined);
    vi.stubEnv("DATABASE_URL", "postgres://fake:fake@localhost/fake");
    vi.stubEnv("DATABASE_RETRY_MAX", "2");
    vi.stubEnv("DATABASE_RETRY_BASE_MS", "1");
    vi.stubEnv("DATABASE_RETRY_MAX_MS", "2");
  });

  afterEach(() => {
    vi.doUnmock("postgres");
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  it("retries a connection-establishment error and succeeds once it clears", async () => {
    vi.doMock("postgres", () => ({
      default: () => mockPostgresFactory((call) =>
        call === 1
          ? Object.assign(Promise.reject(connectionError("ECONNREFUSED")), { executed: false })
          : Object.assign(Promise.resolve([{ answer: 1 }]), { executed: false })
      ),
    }));

    const { sql } = await import("./db");
    await expect(sql`SELECT 1 AS answer`).resolves.toEqual([{ answer: 1 }]);
  });

  it("gives up after exhausting the retry budget on a persistent connection error", async () => {
    vi.doMock("postgres", () => ({
      default: () => mockPostgresFactory(() =>
        Object.assign(Promise.reject(connectionError("ECONNREFUSED")), { executed: false })
      ),
    }));

    const { sql } = await import("./db");
    await expect(sql`SELECT 1`).rejects.toMatchObject({ code: "ECONNREFUSED" });
  });

  it("does not retry an error that isn't connection-related", async () => {
    let calls = 0;
    vi.doMock("postgres", () => ({
      default: () => mockPostgresFactory(() => {
        calls += 1;
        return Object.assign(Promise.reject(Object.assign(new Error("syntax error"), { code: "42601" })), { executed: false });
      }),
    }));

    const { sql } = await import("./db");
    await expect(sql`NOT VALID SQL`).rejects.toMatchObject({ code: "42601" });
    expect(calls).toBe(1);
  });

  it("warns in production when DATABASE_URL is not a Neon pooled endpoint", async () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.stubEnv("DATABASE_URL", "postgres://user:pass@ep-example.us-east-2.aws.neon.tech/db?sslmode=require");
    vi.doMock("postgres", () => ({ default: () => mockPostgresFactory(() => Promise.resolve([])) }));

    // resetModules() gives db.ts a fresh copy of lib/logger too — import it here (before db.ts,
    // so the cache is primed with this instance) to spy on the exact logger db.ts will call.
    const { default: freshLogger } = await import("@/lib/logger");
    const warnSpy = vi.spyOn(freshLogger, "warn").mockImplementation(() => {});

    await import("./db");

    expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining("does not target a Neon pooled"));
    warnSpy.mockRestore();
  });

  it("does not warn when DATABASE_URL already targets a pooled endpoint", async () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.stubEnv("DATABASE_URL", "postgres://user:pass@ep-example-pooler.us-east-2.aws.neon.tech/db?sslmode=require");
    vi.doMock("postgres", () => ({ default: () => mockPostgresFactory(() => Promise.resolve([])) }));

    const { default: freshLogger } = await import("@/lib/logger");
    const warnSpy = vi.spyOn(freshLogger, "warn").mockImplementation(() => {});

    await import("./db");

    expect(warnSpy).not.toHaveBeenCalledWith(expect.stringContaining("does not target a Neon pooled"));
    warnSpy.mockRestore();
  });
});
