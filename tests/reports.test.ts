import { describe, it, expect, vi, beforeEach } from "vitest";
import { createObstructionReport, fetchCampusReports } from "@/lib/spatial/reports";
import { sql } from "@/lib/db";

vi.mock("@/lib/db", () => {
  const sqlMock = vi.fn();
  return { sql: sqlMock };
});

describe("Spatial Queries - Reports", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("creates a report for a room", async () => {
    const mockReport = {
      id: "123e4567-e89b-12d3-a456-426614174000",
      room_id: "123e4567-e89b-12d3-a456-426614174001",
      edge_id: null,
      description: "Door blocked",
      status: "open",
      reported_at: new Date("2026-01-01T00:00:00.000Z"),
      resolved_at: null,
    };

    (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce([mockReport]);

    const result = await createObstructionReport({
      roomId: "123e4567-e89b-12d3-a456-426614174001",
      description: "Door blocked",
    });

    expect(result.description).toBe("Door blocked");
    expect(result.room_id).toBe("123e4567-e89b-12d3-a456-426614174001");
    expect(result.status).toBe("open");
    expect(result.resolved_at).toBeNull();
  });

  it("creates a report with optional GPS location", async () => {
    const mockReport = {
      id: "123e4567-e89b-12d3-a456-426614174000",
      room_id: null,
      edge_id: "123e4567-e89b-12d3-a456-426614174002",
      description: "Stairs blocked",
      status: "open",
      reported_at: new Date("2026-01-01T00:00:00.000Z"),
      resolved_at: null,
    };

    (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce([mockReport]);

    const result = await createObstructionReport({
      edgeId: "123e4567-e89b-12d3-a456-426614174002",
      description: "Stairs blocked",
      lng: -73.985,
      lat: 40.748,
    });

    expect(result.edge_id).toBe("123e4567-e89b-12d3-a456-426614174002");
    const sqlCallStrings = (sql as unknown as ReturnType<typeof vi.fn>).mock.calls[0][0] as string[];
    expect(sqlCallStrings.join("")).toContain("ST_MakePoint");
  });

  it("fetches open reports for a campus", async () => {
    const mockRows = [
      { id: "123e4567-e89b-12d3-a456-426614174003", room_id: "123e4567-e89b-12d3-a456-426614174001", edge_id: null, description: "Door blocked", status: "open", reported_at: new Date("2026-01-02"), resolved_at: null },
      { id: "123e4567-e89b-12d3-a456-426614174004", room_id: null, edge_id: "123e4567-e89b-12d3-a456-426614174002", description: "Corridor blocked", status: "open", reported_at: new Date("2026-01-01"), resolved_at: null },
    ];

    (sql as unknown as ReturnType<typeof vi.fn>)
      .mockResolvedValueOnce([{ total: 2 }])
      .mockResolvedValueOnce(mockRows);

    const { reports, total } = await fetchCampusReports("campus-1", "open", 0, 20);

    expect(total).toBe(2);
    expect(reports).toHaveLength(2);
    expect(reports[0].status).toBe("open");
    expect(reports[1].description).toBe("Corridor blocked");
    for (const [strings] of (sql as unknown as ReturnType<typeof vi.fn>).mock.calls) {
      expect(strings.join("")).toContain("LEFT JOIN routing_edges e ON r.edge_id = e.id");
      expect(strings.join("")).toContain("OR edge_building.campus_id");
    }
  });

  it("returns empty when no reports match", async () => {
    (sql as unknown as ReturnType<typeof vi.fn>)
      .mockResolvedValueOnce([{ total: 0 }])
      .mockResolvedValueOnce([]);

    const { reports, total } = await fetchCampusReports("campus-1", "resolved");

    expect(total).toBe(0);
    expect(reports).toHaveLength(0);
  });
});
