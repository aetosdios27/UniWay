import { beforeEach, describe, expect, it, vi } from "vitest";
import { fetchMapPois, MapPoiSchema } from "./map-pois";
import { sql } from "@/lib/db";

vi.mock("@/lib/db", () => {
  const sqlMock = vi.fn();
  return { sql: sqlMock };
});

const campusId = "11111111-1111-4111-8111-111111111111";

describe("fetchMapPois", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("fetches all POIs for a campus ordered by name and id", async () => {
    const rawRows = [
      {
        id: "poi_01",
        name: "Academic Office",
        category: "dome",
        icon_key: "dome",
        tags: ["office"],
        routing_node_id: "OUT_ADM_0_092",
        geom: { type: "Point", coordinates: [75.565, 26.841] },
      },
      {
        id: "poi_02",
        name: "Campus Eatery",
        category: "food",
        icon_key: null,
        tags: [],
        routing_node_id: null,
        geom: { type: "Point", coordinates: [75.566, 26.842] },
      },
    ];

    (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce(rawRows);

    const result = await fetchMapPois(campusId);
    expect(result).toHaveLength(2);
    expect(result[0].id).toBe("poi_01");
    expect(result[0].tags).toEqual(["office"]);
    expect(result[1].icon_key).toBeNull();
    expect(result[1].routing_node_id).toBeNull();
    expect(sql).toHaveBeenCalledTimes(1);
  });

  it("applies category filter when provided", async () => {
    (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce([]);

    const result = await fetchMapPois(campusId, "food");
    expect(result).toEqual([]);
    expect(sql).toHaveBeenCalledTimes(1);
  });

  it("rejects database rows that violate schema", async () => {
    const invalidRow = {
      id: "poi_01",
      name: "Bad POI",
      category: "food",
      icon_key: "invalid_key", // invalid icon_key
      tags: [],
      routing_node_id: null,
      geom: { type: "Point", coordinates: [75.565, 26.841] },
    };

    (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce([invalidRow]);

    await expect(fetchMapPois(campusId)).rejects.toThrow();
  });
});

describe("MapPoiSchema", () => {
  it("parses valid row with null icon_key and routing_node_id", () => {
    const parsed = MapPoiSchema.parse({
      id: "p1",
      name: "Test",
      category: "amenities",
      icon_key: null,
      tags: [],
      routing_node_id: null,
      geom: { type: "Point", coordinates: [75.5, 26.8] },
    });
    expect(parsed.icon_key).toBeNull();
    expect(parsed.routing_node_id).toBeNull();
    expect(parsed.tags).toEqual([]);
  });

  it("defaults missing tags to empty array", () => {
    const parsed = MapPoiSchema.parse({
      id: "p1",
      name: "Test",
      category: "sports",
      geom: { type: "Point", coordinates: [75.5, 26.8] },
    });
    expect(parsed.tags).toEqual([]);
    expect(parsed.icon_key).toBeNull();
    expect(parsed.routing_node_id).toBeNull();
  });
});
