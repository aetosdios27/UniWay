import { beforeEach, expect, it, vi } from "vitest";
import { GET } from "@/app/api/campus/[id]/node-route/route";
import { GET as destinations } from "@/app/api/campus/[id]/destinations/route";
import { isPointInCampus } from "@/lib/spatial/campus";
import { getNearestRoutingNode, fetchRoutingDestinations } from "@/lib/spatial/nodes";
import { findNodeRoute } from "@/lib/routing/nodes";
import { withRateLimit } from "@/lib/rate-limit";

vi.mock("@/lib/spatial/campus", () => ({ isPointInCampus: vi.fn() }));
vi.mock("@/lib/spatial/nodes", () => ({ getNearestRoutingNode: vi.fn(), fetchRoutingDestinations: vi.fn() }));
vi.mock("@/lib/routing/nodes", () => ({ findNodeRoute: vi.fn() }));
vi.mock("@/lib/rate-limit", () => ({ withRateLimit: vi.fn() }));
const campusId = "11111111-1111-4111-8111-111111111111";
const params = { params: Promise.resolve({ id: campusId }) };
const request = (query = "fromLng=75.56&fromLat=26.84&toNodeId=OUT_AB1_0_001") => new Request(`http://localhost/api/campus/${campusId}/node-route?${query}`);
const route = { type: "Feature" as const, properties: { distance_meters: 5 }, geometry: { type: "LineString" as const, coordinates: [[75.56, 26.84], [75.57, 26.84]] as [number, number][] } };

beforeEach(() => {
  vi.resetAllMocks();
  vi.mocked(isPointInCampus).mockResolvedValue(true);
  vi.mocked(getNearestRoutingNode).mockResolvedValue({ node_id: "OUT_AB1_0_002" } as Awaited<ReturnType<typeof getNearestRoutingNode>>);
  vi.mocked(findNodeRoute).mockResolvedValue(route);
});

it("returns geometry with campus-scoped snapping, floor and accessibility", async () => {
  const response = await GET(request("fromLng=75.56&fromLat=26.84&toNodeId=OUT_AB1_0_001&floor=1&accessible=true"), params);
  expect(await response.json()).toEqual({ data: route });
  expect(response.headers.get("Cache-Control")).toBe("no-store");
  expect(getNearestRoutingNode).toHaveBeenCalledWith(campusId, 75.56, 26.84, "1", true);
  expect(findNodeRoute).toHaveBeenCalledWith(campusId, "OUT_AB1_0_002", "OUT_AB1_0_001", true);
});

it("rejects invalid input before accessing the database", async () => {
  expect((await GET(request("fromLng=NaN&fromLat=26&toNodeId=x"), params)).status).toBe(400);
  expect((await GET(request(), { params: Promise.resolve({ id: "bad" }) })).status).toBe(400);
  expect(isPointInCampus).not.toHaveBeenCalled();
});

it("returns 404 for outside-campus, absent snap and unreachable destination", async () => {
  vi.mocked(isPointInCampus).mockResolvedValueOnce(false);
  expect((await GET(request(), params)).status).toBe(404);
  vi.mocked(getNearestRoutingNode).mockResolvedValueOnce(null);
  expect((await GET(request(), params)).status).toBe(404);
  vi.mocked(findNodeRoute).mockResolvedValueOnce(null);
  expect((await GET(request(), params)).status).toBe(404);
});

it("handles database errors and rate limits", async () => {
  vi.mocked(findNodeRoute).mockRejectedValueOnce(new Error("db failed"));
  expect((await GET(request(), params)).status).toBe(500);
  vi.mocked(withRateLimit).mockReturnValue(new Response(null, { status: 429 }) as ReturnType<typeof withRateLimit>);
  expect((await GET(request(), params)).status).toBe(429);
  expect((await destinations(request(), params)).status).toBe(429);
});

it("lists destinations for the requested campus and handles invalid IDs/errors", async () => {
  vi.mocked(fetchRoutingDestinations).mockResolvedValue([]);
  expect(await (await destinations(request(), params)).json()).toEqual({ data: [] });
  expect(fetchRoutingDestinations).toHaveBeenCalledWith(campusId);
  expect((await destinations(request(), { params: Promise.resolve({ id: "bad" }) })).status).toBe(400);
  vi.mocked(fetchRoutingDestinations).mockRejectedValueOnce(new Error("db failed"));
  expect((await destinations(request(), params)).status).toBe(500);
});
