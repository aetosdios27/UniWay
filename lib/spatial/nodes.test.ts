import { beforeEach, describe, expect, it, vi } from "vitest";
import { fetchNodeEdges, fetchRoutingDestinations, fetchRoutingNodes, getNearestRoutingNode } from "./nodes";
import { sql } from "@/lib/db";

vi.mock("@/lib/db", () => {
  const sqlMock = vi.fn();
  return { sql: sqlMock };
});

const campusId = "11111111-1111-4111-8111-111111111111";

describe("fetchRoutingDestinations", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns destinations with category, icon_key, and tags", async () => {
    const rawRows = [
      {
        id: "DEST_01",
        name: "Dome Building",
        type: "destination",
        routing_node_id: "OUT_ADM_0_092",
        category: "dome",
        icon_key: "dome",
        tags: ["admin_office"],
        geom: { type: "Point", coordinates: [75.565927, 26.8416371] },
      },
      {
        id: "DEST_02",
        name: "Old Mess",
        type: "destination",
        routing_node_id: "OUT_EAT_0_118",
        category: "food",
        icon_key: null,
        tags: [],
        geom: { type: "Point", coordinates: [75.5653374, 26.842961] },
      },
    ];

    (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce(rawRows);

    const result = await fetchRoutingDestinations(campusId);
    expect(result).toHaveLength(2);
    expect(result[0]).toEqual({
      id: "DEST_01",
      name: "Dome Building",
      type: "destination",
      routing_node_id: "OUT_ADM_0_092",
      category: "dome",
      icon_key: "dome",
      tags: ["admin_office"],
      geom: { type: "Point", coordinates: [75.565927, 26.8416371] },
    });
    expect(result[1].icon_key).toBeNull();
    expect(result[1].tags).toEqual([]);
  });
});

const nodeRow = {
  campus_id: campusId,
  node_id: "OUT_ADM_0_092",
  nid: 92,
  loc: "Dome Building",
  node_type: "entrance",
  floor_id: "0",
  is_accessible: true,
  geom: { type: "Point", coordinates: [75.565927, 26.8416371] },
};

describe("routing node queries", () => {
  const mockSql = sql as unknown as ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("fetchRoutingNodes parses node rows", async () => {
    mockSql.mockResolvedValueOnce([nodeRow]);

    await expect(fetchRoutingNodes(campusId)).resolves.toEqual([nodeRow]);
  });

  it("fetchNodeEdges parses edge rows", async () => {
    const edge = {
      edge_id: "E1",
      source_node_id: "OUT_ADM_0_092",
      target_node_id: "OUT_ADM_0_093",
      distance_meters: 12.5,
      is_accessible: true,
      floor_id: "0",
      edge_type: "walkway",
      geom: { type: "LineString", coordinates: [[75.5659, 26.8416], [75.566, 26.8417]] },
    };
    mockSql.mockResolvedValueOnce([edge]);

    await expect(fetchNodeEdges(campusId)).resolves.toEqual([edge]);
  });

  it("getNearestRoutingNode returns the closest node, or null when none is in range", async () => {
    mockSql.mockResolvedValueOnce([nodeRow]);
    await expect(getNearestRoutingNode(campusId, 75.5659, 26.8416, "0", false)).resolves.toEqual(nodeRow);

    mockSql.mockResolvedValueOnce([]);
    await expect(getNearestRoutingNode(campusId, 0, 0, "0", true)).resolves.toBeNull();
  });
});
