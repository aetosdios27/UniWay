import { beforeEach, describe, expect, it, vi } from "vitest";
import { GET as mapPoisGet } from "@/app/api/campus/[id]/map-pois/route";
import { GET as destinationsGet } from "@/app/api/campus/[id]/destinations/route";
import { fetchMapPois, MapPoi } from "@/lib/spatial/map-pois";
import { fetchRoutingDestinations } from "@/lib/spatial/nodes";
import { withRateLimit } from "@/lib/rate-limit";

vi.mock("@/lib/spatial/map-pois", () => ({
  fetchMapPois: vi.fn(),
}));

vi.mock("@/lib/spatial/nodes", () => ({
  fetchRoutingDestinations: vi.fn(),
}));

vi.mock("@/lib/rate-limit", () => ({
  withRateLimit: vi.fn(),
}));

const campusId = "11111111-1111-4111-8111-111111111111";
const params = { params: Promise.resolve({ id: campusId }) };
const poiRequest = (query = "") =>
  new Request(`http://localhost/api/campus/${campusId}/map-pois${query ? `?${query}` : ""}`);
const destRequest = () =>
  new Request(`http://localhost/api/campus/${campusId}/destinations`);

describe("GET /api/campus/[id]/map-pois", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns 400 when campus ID is not a valid UUID", async () => {
    const response = await mapPoisGet(poiRequest(), { params: Promise.resolve({ id: "invalid-uuid" }) });
    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.error).toBe("Invalid campus ID");
    expect(fetchMapPois).not.toHaveBeenCalled();
  });

  it("returns 400 when category parameter exceeds 50 characters", async () => {
    const longCategory = "a".repeat(51);
    const response = await mapPoisGet(poiRequest(`category=${longCategory}`), params);
    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.error).toBe("category must be at most 50 characters");
    expect(fetchMapPois).not.toHaveBeenCalled();
  });

  it("enforces rate limits", async () => {
    vi.mocked(withRateLimit).mockReturnValueOnce(
      new Response(JSON.stringify({ error: "Too many requests" }), { status: 429 }) as ReturnType<typeof withRateLimit>
    );
    const response = await mapPoisGet(poiRequest(), params);
    expect(response.status).toBe(429);
    expect(fetchMapPois).not.toHaveBeenCalled();
  });

  it("returns 500 when fetchMapPois throws", async () => {
    vi.mocked(fetchMapPois).mockRejectedValueOnce(new Error("DB failure"));
    const response = await mapPoisGet(poiRequest(), params);
    expect(response.status).toBe(500);
    const body = await response.json();
    expect(body.error).toBe("Internal Server Error");
  });

  it("returns POIs with cache headers and expected shape including nulls and tags", async () => {
    const samplePois: MapPoi[] = [
      {
        id: "poi_01",
        name: "Central Library",
        category: "academic",
        icon_key: "academic",
        tags: ["quiet", "study"],
        routing_node_id: "OUT_LIB_0_091",
        geom: { type: "Point", coordinates: [75.566, 26.842] },
      },
      {
        id: "poi_02",
        name: "Campus ATM",
        category: "amenities",
        icon_key: null,
        tags: [],
        routing_node_id: null,
        geom: { type: "Point", coordinates: [75.565, 26.841] },
      },
    ];

    vi.mocked(fetchMapPois).mockResolvedValueOnce(samplePois);
    const response = await mapPoisGet(poiRequest(), params);
    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toContain("max-age=300");

    const body = await response.json();
    expect(body).toEqual({ data: samplePois });
    expect(fetchMapPois).toHaveBeenCalledWith(campusId, undefined);
  });

  it("passes category filter to fetchMapPois when provided", async () => {
    vi.mocked(fetchMapPois).mockResolvedValueOnce([]);
    const response = await mapPoisGet(poiRequest("category=food"), params);
    expect(response.status).toBe(200);
    expect(fetchMapPois).toHaveBeenCalledWith(campusId, "food");
  });

  it.each(["category=", "category=%20", "category=%20%20%09"])(
    "treats blank category %s as no filter",
    async (query) => {
      vi.mocked(fetchMapPois).mockResolvedValueOnce([]);
      const response = await mapPoisGet(poiRequest(query), params);
      expect(response.status).toBe(200);
      expect(fetchMapPois).toHaveBeenCalledWith(campusId, undefined);
    },
  );

  it("trims whitespace around a category before filtering", async () => {
    vi.mocked(fetchMapPois).mockResolvedValueOnce([]);
    await mapPoisGet(poiRequest("category=%20food%20"), params);
    expect(fetchMapPois).toHaveBeenCalledWith(campusId, "food");
  });
});

describe("GET /api/campus/[id]/destinations with new fields", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns destinations including category, icon_key, and tags", async () => {
    const sampleDestinations = [
      {
        id: "DEST_01",
        name: "Dome Building",
        type: "destination" as const,
        routing_node_id: "OUT_ADM_0_092",
        category: "dome",
        icon_key: "dome",
        tags: ["administrative"],
        geom: { type: "Point" as const, coordinates: [75.565927, 26.8416371] as [number, number] },
      },
      {
        id: "DEST_02",
        name: "Unknown Hall",
        type: "destination" as const,
        routing_node_id: "OUT_UNK_0_001",
        category: null,
        icon_key: null,
        tags: [],
        geom: { type: "Point" as const, coordinates: [75.565, 26.841] as [number, number] },
      },
    ];

    vi.mocked(fetchRoutingDestinations).mockResolvedValueOnce(sampleDestinations);
    const response = await destinationsGet(destRequest(), params);
    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toContain("max-age=300");

    const body = await response.json();
    expect(body).toEqual({ data: sampleDestinations });
    expect(fetchRoutingDestinations).toHaveBeenCalledWith(campusId);
  });
});
