import { beforeEach, describe, expect, it, vi } from "vitest";
import { GET } from "@/app/api/health/route";
import { sql } from "@/lib/db";

vi.mock("@/lib/db", () => ({ sql: vi.fn() }));

describe("GET /api/health", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("reports ok when the database answers", async () => {
    (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce([{ "?column?": 1 }]);

    const response = await GET();
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(body.status).toBe("ok");
    expect(body.db).toBe("up");
    expect(body.latencyMs).toBeTypeOf("number");
  });

  it("reports degraded with a 503 when the database is unreachable", async () => {
    (sql as unknown as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error("connect ECONNREFUSED"));

    const response = await GET();
    const body = await response.json();

    expect(response.status).toBe(503);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(body.status).toBe("degraded");
    expect(body.db).toBe("down");
    expect(body.error).toContain("ECONNREFUSED");
  });
});
