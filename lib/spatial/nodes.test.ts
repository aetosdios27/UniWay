import { beforeEach, describe, expect, it, vi } from "vitest";
import { fetchRoutingDestinations } from "./nodes";
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
