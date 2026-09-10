import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { GET } from "@/app/api/health/route";
import { sql } from "@/lib/db";

vi.mock("@/lib/db", () => ({ sql: vi.fn() }));

const request = (headers: HeadersInit = {}) => new Request("http://localhost/api/health", { headers });

describe("GET /api/health", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("reports ok when the database answers", async () => {
    (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce([{ "?column?": 1 }]);

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(body.status).toBe("ok");
    expect(body.db).toBe("up");
    expect(body.latencyMs).toBeTypeOf("number");
  });

  it("reports degraded with a 503 and the raw error outside production", async () => {
    (sql as unknown as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error("connect ECONNREFUSED"));

    const response = await GET(request({ "x-request-id": "req-123" }));
    const body = await response.json();

    expect(response.status).toBe(503);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("X-Request-Id")).toBe("req-123");
    expect(body.status).toBe("degraded");
    expect(body.db).toBe("down");
    expect(body.error).toContain("ECONNREFUSED");
    expect(body.requestId).toBe("req-123");
  });

  it("hides connection details behind a generic message in production", async () => {
    vi.stubEnv("NODE_ENV", "production");
    (sql as unknown as ReturnType<typeof vi.fn>).mockRejectedValueOnce(
      new Error("connect ECONNREFUSED ep-example.us-east-2.aws.neon.tech:5432")
    );

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(503);
    expect(body.error).toBe("Database unreachable");
    expect(body.error).not.toContain("neon.tech");
  });
});
