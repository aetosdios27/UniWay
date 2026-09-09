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
