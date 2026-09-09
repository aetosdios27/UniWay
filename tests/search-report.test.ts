import { describe, it, expect, vi, beforeEach } from "vitest";
import { GET as searchPois } from "@/app/api/search/route";
import { POST as createReport } from "@/app/api/report/route";
import { GET as listCampusReports } from "@/app/api/campus/[id]/reports/route";
import { sql } from "@/lib/db";

vi.mock("@/lib/db", () => ({
  sql: vi.fn(),
}));

vi.mock("@/lib/rate-limit", () => ({
  withRateLimit: vi.fn().mockReturnValue(null),
}));

const mockSql = sql as unknown as ReturnType<typeof vi.fn>;
const req = (url = "http://localhost") => new Request(url);

describe("GET /api/search", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns 400 if q is missing", async () => {
    const response = await searchPois(req("http://localhost/api/search?campus=123e4567-e89b-12d3-a456-426614174000"));
    expect(response.status).toBe(400);
  });

  it("returns 400 if campus is missing", async () => {
    const response = await searchPois(req("http://localhost/api/search?q=lab"));
    expect(response.status).toBe(400);
  });

  it("returns 400 if campus is not a valid UUID", async () => {
    const response = await searchPois(req("http://localhost/api/search?q=lab&campus=not-a-uuid"));
    expect(response.status).toBe(400);
  });

  it("returns results with pagination", async () => {
    const mockResult = { id: "123e4567-e89b-12d3-a456-426614174001", room_id: "123e4567-e89b-12d3-a456-426614174002", name: "CS Lab", category: "lab", tags: [], rank: 0.5, floor: "1", building_id: "123e4567-e89b-12d3-a456-426614174001", building_name: "Engineering Building" };
    mockSql.mockResolvedValueOnce([{ total: 1 }]);
    mockSql.mockResolvedValueOnce([mockResult]);

    const response = await searchPois(req("http://localhost/api/search?q=lab&campus=123e4567-e89b-12d3-a456-426614174000"));
    const json = await response.json();

    expect(response.status).toBe(200);
    expect(json.data).toHaveLength(1);
    expect(json.data[0].name).toBe("CS Lab");
    expect(json.data[0].floor).toBe("1");
    expect(json.data[0].building_name).toBe("Engineering Building");
    expect(json.pagination).toEqual({ offset: 0, limit: 20, total: 1 });
  });

  it("handles empty results", async () => {
    mockSql.mockResolvedValueOnce([{ total: 0 }]);
    mockSql.mockResolvedValueOnce([]);

    const response = await searchPois(req("http://localhost/api/search?q=xyz&campus=123e4567-e89b-12d3-a456-426614174000"));
    const json = await response.json();

    expect(response.status).toBe(200);
    expect(json.data).toHaveLength(0);
    expect(json.pagination.total).toBe(0);
  });

  it("respects custom pagination params", async () => {
    mockSql.mockResolvedValueOnce([{ total: 50 }]);
    mockSql.mockResolvedValueOnce([]);

    const response = await searchPois(req("http://localhost/api/search?q=lab&campus=123e4567-e89b-12d3-a456-426614174000&limit=5&offset=10"));
    const json = await response.json();

    expect(json.pagination.limit).toBe(5);
    expect(json.pagination.offset).toBe(10);
  });

  it("caps limit at max", async () => {
    mockSql.mockResolvedValueOnce([{ total: 50 }]);
    mockSql.mockResolvedValueOnce([]);

    const response = await searchPois(req("http://localhost/api/search?q=lab&campus=123e4567-e89b-12d3-a456-426614174000&limit=999"));
    const json = await response.json();

    expect(json.pagination.limit).toBe(50);
  });

  it("handles errors gracefully", async () => {
    mockSql.mockRejectedValueOnce(new Error("DB Error"));

    const response = await searchPois(req("http://localhost/api/search?q=lab&campus=123e4567-e89b-12d3-a456-426614174000"));
    expect(response.status).toBe(500);
  });
});

describe("POST /api/report", () => {
  const validBody = { description: "Door blocked", roomId: "123e4567-e89b-12d3-a456-426614174001" };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns 413 if content-length exceeds limit", async () => {
    const largeBody = "x".repeat(20_000);
    const response = await createReport(new Request("http://localhost", { method: "POST", body: largeBody }));
    expect(response.status).toBe(413);
  });

  it("returns 400 if body is invalid JSON", async () => {
    const headers = new Headers({ "content-length": "5" });
    const badJson = "{bad}";
    const response = await createReport(new Request("http://localhost", { method: "POST", headers, body: badJson }));
    expect(response.status).toBe(400);
  });

  it("returns 400 if body has validation errors", async () => {
    const headers = new Headers({ "content-length": "20" });
    const empty = JSON.stringify({});
    const response = await createReport(new Request("http://localhost", { method: "POST", headers, body: empty }));
    expect(response.status).toBe(400);
  });

  it("creates a report successfully", async () => {
    const mockReport = { id: "123e4567-e89b-12d3-a456-426614174000", room_id: "123e4567-e89b-12d3-a456-426614174001", edge_id: null, description: "Door blocked", status: "open", reported_at: new Date(), resolved_at: null };
    mockSql.mockResolvedValueOnce([mockReport]);

    const headers = new Headers({ "content-length": "100" });
    const response = await createReport(new Request("http://localhost", { method: "POST", headers, body: JSON.stringify(validBody) }));
    const json = await response.json();

    expect(response.status).toBe(201);
    expect(json.data.description).toBe("Door blocked");
  });

  it("handles database errors gracefully", async () => {
    mockSql.mockRejectedValueOnce(new Error("DB Error"));

    const headers = new Headers({ "content-length": "100" });
    const response = await createReport(new Request("http://localhost", { method: "POST", headers, body: JSON.stringify(validBody) }));
    expect(response.status).toBe(500);
  });
});

describe("GET /api/campus/[id]/reports", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns open reports with pagination", async () => {
    const mockRows = [
      { id: "123e4567-e89b-12d3-a456-426614174003", room_id: "123e4567-e89b-12d3-a456-426614174001", edge_id: null, description: "Door blocked", status: "open", reported_at: new Date("2026-01-02"), resolved_at: null },
    ];
    mockSql.mockResolvedValueOnce([{ total: 1 }]);
    mockSql.mockResolvedValueOnce(mockRows);

    const response = await listCampusReports(req("http://localhost/api/campus/campus-1/reports"), { params: Promise.resolve({ id: "campus-1" }) });
    const json = await response.json();

    expect(response.status).toBe(200);
    expect(json.data).toHaveLength(1);
    expect(json.data[0].status).toBe("open");
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(json.pagination).toEqual({ offset: 0, limit: 20, total: 1 });
  });

  it("filters by status", async () => {
    mockSql.mockResolvedValueOnce([{ total: 0 }]);
    mockSql.mockResolvedValueOnce([]);

    const response = await listCampusReports(req("http://localhost/api/campus/campus-1/reports?status=resolved"), { params: Promise.resolve({ id: "campus-1" }) });
    const json = await response.json();

    expect(response.status).toBe(200);
    expect(json.data).toHaveLength(0);
  });

  it("handles errors gracefully", async () => {
    mockSql.mockRejectedValueOnce(new Error("DB Error"));

    const response = await listCampusReports(req("http://localhost/api/campus/campus-1/reports"), { params: Promise.resolve({ id: "campus-1" }) });
    expect(response.status).toBe(500);
  });
});
