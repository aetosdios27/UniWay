import { describe, it, expect, vi, beforeEach } from "vitest";
import { GET as getCampuses } from "@/app/api/campus/route";
import { GET as getContainingCampus } from "@/app/api/campus/containing/route";
import { GET as getCampusMetadata } from "@/app/api/campus/[id]/route";
import { GET as getBuildings } from "@/app/api/campus/[id]/buildings/route";
import { GET as getRooms } from "@/app/api/campus/[id]/rooms/route";
import { GET as getCampusRoute } from "@/app/api/campus/[id]/route/route";
import { GET as getPois } from "@/app/api/campus/[id]/pois/route";
import { GET as getRoute } from "@/app/api/route/route";
import { GET as getNearby } from "@/app/api/campus/[id]/nearby/route";
import { GET as getRoomDetail } from "@/app/api/rooms/[id]/route";
import { GET as getPoiDetail } from "@/app/api/pois/[id]/route";
import { sql } from "@/lib/db";
import { getNearestRoom } from "@/lib/spatial/knn";
import { findShortestPath } from "@/lib/routing/graph";
import { isPointInCampus } from "@/lib/spatial/campus";
import { fetchRoomById } from "@/lib/spatial/rooms";
import { fetchPoiById } from "@/lib/spatial/pois";
import { mockPolygon, mockPoint } from "./fixtures/geojson";

vi.mock("@/lib/db", () => ({
  sql: vi.fn(),
}));

vi.mock("@/lib/spatial/knn", () => ({
  getNearestRoom: vi.fn(),
}));

vi.mock("@/lib/routing/graph", () => ({
  findShortestPath: vi.fn(),
}));

vi.mock("@/lib/spatial/campus", async () => {
  const actual = await vi.importActual<typeof import("@/lib/spatial/campus")>("@/lib/spatial/campus");
  return {
    ...actual,
    isPointInCampus: vi.fn().mockResolvedValue(true),
  };
});

vi.mock("@/lib/spatial/rooms", async () => {
  const actual = await vi.importActual<typeof import("@/lib/spatial/rooms")>("@/lib/spatial/rooms");
  return {
    ...actual,
    fetchRoomById: vi.fn(),
  };
});

vi.mock("@/lib/spatial/pois", async () => {
  const actual = await vi.importActual<typeof import("@/lib/spatial/pois")>("@/lib/spatial/pois");
  return {
    ...actual,
    fetchPoiById: vi.fn(),
  };
});

vi.mock("@/lib/rate-limit", () => ({
  withRateLimit: vi.fn().mockReturnValue(null),
}));

const mockSql = sql as unknown as ReturnType<typeof vi.fn>;
const mockGetNearestRoom = getNearestRoom as unknown as ReturnType<typeof vi.fn>;
const mockFindShortestPath = findShortestPath as unknown as ReturnType<typeof vi.fn>;
const mockFetchRoomById = fetchRoomById as unknown as ReturnType<typeof vi.fn>;
const mockFetchPoiById = fetchPoiById as unknown as ReturnType<typeof vi.fn>;
const req = (url = "http://localhost") => new Request(url);
const params = (id: string) => ({ params: Promise.resolve({ id }) });
const TEST_ROOM_ID = "123e4567-e89b-12d3-a456-426614174003";

describe("API Routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("GET /api/campus", () => {
    it("returns a list of campuses", async () => {
      const mockCampus = { id: "123e4567-e89b-12d3-a456-426614174000", name: "Main Campus", bounds: { type: "Polygon", coordinates: [] } };
      mockSql.mockResolvedValueOnce([mockCampus]);

      const response = await getCampuses(req());
      const json = await response.json();

      expect(response.status).toBe(200);
      expect(json.data).toHaveLength(1);
      expect(json.data[0].id).toBe(mockCampus.id);
    });

    it("handles errors gracefully", async () => {
      mockSql.mockRejectedValueOnce(new Error("DB Error"));

      const response = await getCampuses(req());
      const json = await response.json();

      expect(response.status).toBe(500);
      expect(json.error).toBe("Internal Server Error");
    });
  });

  describe("GET /api/campus/containing", () => {
    it("returns 400 if lat/lng missing", async () => {
      const response = await getContainingCampus(req());
      expect(response.status).toBe(400);
    });

    it("returns 400 if lat/lng not valid numbers", async () => {
      const response = await getContainingCampus(req("http://localhost/api/campus/containing?lat=abc&lng=def"));
      expect(response.status).toBe(400);
    });

    it("returns null if no campus contains point", async () => {
      mockSql.mockResolvedValueOnce([]);
      const response = await getContainingCampus(req("http://localhost/api/campus/containing?lat=40.74&lng=-73.98"));
      const json = await response.json();
      expect(response.status).toBe(200);
      expect(json.data).toBeNull();
    });

    it("returns campus if point is within bounds", async () => {
      const mockCampus = { id: "123e4567-e89b-12d3-a456-426614174000", name: "Main Campus", bounds: { type: "Polygon", coordinates: [] } };
      mockSql.mockResolvedValueOnce([mockCampus]);
      const response = await getContainingCampus(req("http://localhost/api/campus/containing?lat=40.74&lng=-73.98"));
      const json = await response.json();
      expect(response.status).toBe(200);
      expect(json.data.name).toBe("Main Campus");
    });
  });

  describe("GET /api/campus/[id]/pois", () => {
    it("returns a list of POIs", async () => {
      const mockPoi = { id: "123e4567-e89b-12d3-a456-426614174001", room_id: "123e4567-e89b-12d3-a456-426614174002", name: "CS Lab", category: "lab", tags: [] };
      mockSql.mockResolvedValueOnce([{ total: 1 }]); // COUNT query
      mockSql.mockResolvedValueOnce([mockPoi]);

      const response = await getPois(req(), params("campus-1"));
      const json = await response.json();

      expect(response.status).toBe(200);
      expect(json.data).toHaveLength(1);
      expect(json.data[0].name).toBe("CS Lab");
    });

    it("handles errors gracefully", async () => {
      mockSql.mockRejectedValueOnce(new Error("DB Error"));

      const response = await getPois(req(), params("campus-1"));
      expect(response.status).toBe(500);
    });
  });

  describe("GET /api/campus/[id]/pois category filter", () => {
    it("filters POIs by category", async () => {
      const mockPoi = { id: "123e4567-e89b-12d3-a456-426614174001", room_id: "123e4567-e89b-12d3-a456-426614174002", name: "CS Lab", category: "lab", tags: [] };
      mockSql.mockResolvedValueOnce([{ total: 1 }]);
      mockSql.mockResolvedValueOnce([mockPoi]);

      const response = await getPois(req("http://localhost/api/campus/campus-1/pois?category=lab"), params("campus-1"));
      const json = await response.json();

      expect(response.status).toBe(200);
      expect(json.data[0].category).toBe("lab");
    });

    it("returns results for unknown category when empty", async () => {
      mockSql.mockResolvedValueOnce([{ total: 0 }]);
      mockSql.mockResolvedValueOnce([]);

      const response = await getPois(req("http://localhost/api/campus/campus-1/pois?category=nonexistent"), params("campus-1"));
      const json = await response.json();

      expect(response.status).toBe(200);
      expect(json.data).toHaveLength(0);
    });
  });

  describe("GET /api/campus/[id]", () => {
    it("returns 404 if campus not found", async () => {
      mockSql.mockResolvedValueOnce([]);

      const response = await getCampusMetadata(req(), params("123e4567-e89b-12d3-a456-426614174000"));
      expect(response.status).toBe(404);
    });
  });

  describe("GET /api/campus/[id]/buildings", () => {
    it("returns buildings for a campus", async () => {
      const mockBuilding = { id: "123e4567-e89b-12d3-a456-426614174001", campus_id: "123e4567-e89b-12d3-a456-426614174000", name: "Engineering Building", outline: mockPolygon };
      mockSql.mockResolvedValueOnce([mockBuilding]);

      const response = await getBuildings(req(), params("campus-1"));
      const json = await response.json();

      expect(response.status).toBe(200);
      expect(json.data).toHaveLength(1);
      expect(json.data[0].name).toBe("Engineering Building");
    });

    it("handles errors gracefully", async () => {
      mockSql.mockRejectedValueOnce(new Error("DB Error"));

      const response = await getBuildings(req(), params("campus-1"));
      expect(response.status).toBe(500);
    });
  });

  describe("GET /api/campus/[id]/rooms", () => {
    it("returns rooms for a campus", async () => {
      const mockRoom = { id: "123e4567-e89b-12d3-a456-426614174002", building_id: "123e4567-e89b-12d3-a456-426614174001", floor: "1", name: "101" };
      // FRAGILE: fetchRooms calls sql three times when buildingId is absent:
      // 1. sql`` empty fragment for building filter (postgres.js returns query fragment,
      //    but vi.fn() treats it as a function call consuming mockResolvedValueOnce)
      // 2. SELECT COUNT(*) for total
      // 3. SELECT data rows with LIMIT/OFFSET
      mockSql.mockResolvedValueOnce([]);
      mockSql.mockResolvedValueOnce([{ total: 1 }]);
      mockSql.mockResolvedValueOnce([mockRoom]);

      const response = await getRooms(req(), params("campus-1"));
      const json = await response.json();

      expect(response.status).toBe(200);
      expect(json.data).toHaveLength(1);
      expect(json.data[0].name).toBe("101");
    });

    it("handles errors gracefully", async () => {
      mockSql.mockRejectedValueOnce(new Error("DB Error"));

      const response = await getRooms(req(), params("campus-1"));
      expect(response.status).toBe(500);
    });
  });

  describe("GET /api/campus/[id]/route", () => {
    it("returns 400 if missing parameters", async () => {
      const response = await getCampusRoute(req(), params("campus-1"));
      expect(response.status).toBe(400);
    });

    it("scopes nearest room search to campus", async () => {
      mockGetNearestRoom.mockResolvedValueOnce({ id: "123e4567-e89b-12d3-a456-426614174000", building_id: "123e4567-e89b-12d3-a456-426614174001", floor: "1", name: "Lobby", geom: null });
      mockFindShortestPath.mockResolvedValueOnce({
        type: "Feature",
        properties: { distance_meters: 10 },
        geometry: { type: "LineString", coordinates: [[0, 0], [1, 1]] },
      });

      const response = await getCampusRoute(req(`http://localhost/api/campus/campus-1/route?fromLng=-73.98&fromLat=40.74&toRoomId=${TEST_ROOM_ID}`), params("campus-1"));
      expect(response.status).toBe(200);

      expect(mockGetNearestRoom).toHaveBeenCalledWith(-73.98, 40.74, "campus-1");
    });

    it("returns 404 if start point is outside campus bounds", async () => {
      const mockIsPointInCampus = isPointInCampus as unknown as ReturnType<typeof vi.fn>;
      mockIsPointInCampus.mockResolvedValueOnce(false);

      const response = await getCampusRoute(req(`http://localhost/api/campus/campus-1/route?fromLng=-73.98&fromLat=40.74&toRoomId=${TEST_ROOM_ID}`), params("campus-1"));
      expect(response.status).toBe(404);
    });

    it("handles errors gracefully", async () => {
      const mockIsPointInCampus = isPointInCampus as unknown as ReturnType<typeof vi.fn>;
      mockIsPointInCampus.mockRejectedValueOnce(new Error("Bounds check crash"));

      const response = await getCampusRoute(req(`http://localhost/api/campus/campus-1/route?fromLng=-73.98&fromLat=40.74&toRoomId=${TEST_ROOM_ID}`), params("campus-1"));
      expect(response.status).toBe(500);
    });
  });

  describe("GET /api/campus/[id]/nearby", () => {
    it.each(["pois", "rooms"])("paginates %s without changing the total", async (type) => {
      const items = Array.from({ length: 3 }, (_, i) => ({
        id: `123e4567-e89b-12d3-a456-42661417400${i}`,
        room_id: TEST_ROOM_ID, building_id: TEST_ROOM_ID, name: `Place ${i}`,
        category: "lab", tags: [], floor: "0", geom: mockPolygon, centroid: mockPoint,
      }));
      mockSql.mockResolvedValueOnce(items);
      const response = await getNearby(req(`http://localhost/api/campus/campus-1/nearby?lat=40.74&lng=-73.98&type=${type}&offset=1&limit=1`), params("campus-1"));
      const json = await response.json();
      expect(json.data.map((p: { name: string }) => p.name)).toEqual(["Place 1"]);
      expect(json.pagination).toEqual({ offset: 1, limit: 1, total: 3 });
      mockSql.mockResolvedValueOnce(items);
      const beyond = await getNearby(req(`http://localhost/api/campus/campus-1/nearby?lat=40.74&lng=-73.98&type=${type}&offset=9&limit=1`), params("campus-1"));
      expect((await beyond.json()).data).toEqual([]);
    });

    it("returns 400 if missing lat/lng", async () => {
      const response = await getNearby(req(), params("campus-1"));
      expect(response.status).toBe(400);
    });

    it("returns 400 if coordinates out of bounds", async () => {
      const response = await getNearby(req("http://localhost/api/campus/campus-1/nearby?lat=999&lng=-73.98"), params("campus-1"));
      expect(response.status).toBe(400);
    });

    it("returns 404 if point is outside campus", async () => {
      const mockIsPointInCampus = isPointInCampus as unknown as ReturnType<typeof vi.fn>;
      mockIsPointInCampus.mockResolvedValueOnce(false);

      const response = await getNearby(req("http://localhost/api/campus/campus-1/nearby?lat=40.74&lng=-73.98"), params("campus-1"));
      expect(response.status).toBe(404);
    });

    it("returns POIs within radius", async () => {
      const mockPoi = { id: "123e4567-e89b-12d3-a456-426614174001", room_id: "123e4567-e89b-12d3-a456-426614174002", name: "CS Lab", category: "lab", tags: [] };
      mockSql.mockResolvedValueOnce([mockPoi]);

      const response = await getNearby(req("http://localhost/api/campus/campus-1/nearby?lat=40.74&lng=-73.98"), params("campus-1"));
      expect(response.status).toBe(200);

      const json = await response.json();
      expect(json.data).toHaveLength(1);
      expect(json.data[0].name).toBe("CS Lab");
    });

    it("returns rooms within radius", async () => {
      const mockRoom = { id: "123e4567-e89b-12d3-a456-426614174003", building_id: "123e4567-e89b-12d3-a456-426614174001", floor: "1", name: "101", geom: mockPolygon, centroid: mockPoint };
      mockSql.mockResolvedValueOnce([mockRoom]);

      const response = await getNearby(req("http://localhost/api/campus/campus-1/nearby?lat=40.74&lng=-73.98&type=rooms"), params("campus-1"));
      expect(response.status).toBe(200);

      const json = await response.json();
      expect(json.data).toHaveLength(1);
      expect(json.data[0].name).toBe("101");
    });

    it("handles errors gracefully", async () => {
      const mockIsPointInCampus = isPointInCampus as unknown as ReturnType<typeof vi.fn>;
      mockIsPointInCampus.mockRejectedValueOnce(new Error("DB Error"));

      const response = await getNearby(req("http://localhost/api/campus/campus-1/nearby?lat=40.74&lng=-73.98"), params("campus-1"));
      expect(response.status).toBe(500);
    });
  });

  describe("GET /api/rooms/[id]", () => {
    it("returns room with building and campus context", async () => {
      const mockRoom = {
        id: "123e4567-e89b-12d3-a456-426614174003",
        building_id: "123e4567-e89b-12d3-a456-426614174001",
        floor: "1",
        name: "101",
        geom: mockPolygon,
        centroid: mockPoint,
        building_name: "Engineering Building",
        campus_id: "123e4567-e89b-12d3-a456-426614174000",
        campus_name: "Main Campus",
      };
      mockFetchRoomById.mockResolvedValueOnce(mockRoom);

      const response = await getRoomDetail(req(), params("123e4567-e89b-12d3-a456-426614174003"));
      const json = await response.json();

      expect(response.status).toBe(200);
      expect(json.data.name).toBe("101");
      expect(json.data.building_name).toBe("Engineering Building");
      expect(json.data.campus_name).toBe("Main Campus");
      expect(json.data.geom.type).toBe("Polygon");
      expect(json.data.centroid.type).toBe("Point");
    });

    it("returns 404 if room not found", async () => {
      mockFetchRoomById.mockResolvedValueOnce(null);

      const response = await getRoomDetail(req(), params("123e4567-e89b-12d3-a456-426614174003"));
      expect(response.status).toBe(404);
    });

    it("handles errors gracefully", async () => {
      mockFetchRoomById.mockRejectedValueOnce(new Error("DB Error"));

      const response = await getRoomDetail(req(), params("123e4567-e89b-12d3-a456-426614174003"));
      expect(response.status).toBe(500);
    });
  });

  describe("GET /api/pois/[id]", () => {
    it("returns POI with room and building context", async () => {
      const mockPoi = {
        id: "123e4567-e89b-12d3-a456-426614174001",
        room_id: "123e4567-e89b-12d3-a456-426614174003",
        name: "CS Lab",
        category: "lab",
        tags: ["computer", "research"],
        room_name: "101",
        floor: "1",
        building_id: "123e4567-e89b-12d3-a456-426614174001",
        building_name: "Engineering Building",
      };
      mockFetchPoiById.mockResolvedValueOnce(mockPoi);

      const response = await getPoiDetail(req(), params("123e4567-e89b-12d3-a456-426614174001"));
      const json = await response.json();

      expect(response.status).toBe(200);
      expect(json.data.name).toBe("CS Lab");
      expect(json.data.room_name).toBe("101");
      expect(json.data.building_name).toBe("Engineering Building");
      expect(json.data.tags).toEqual(["computer", "research"]);
    });

    it("returns 404 if POI not found", async () => {
      mockFetchPoiById.mockResolvedValueOnce(null);

      const response = await getPoiDetail(req(), params("123e4567-e89b-12d3-a456-426614174001"));
      expect(response.status).toBe(404);
    });

    it("handles errors gracefully", async () => {
      mockFetchPoiById.mockRejectedValueOnce(new Error("DB Error"));

      const response = await getPoiDetail(req(), params("123e4567-e89b-12d3-a456-426614174001"));
      expect(response.status).toBe(500);
    });
  });

  describe("GET /api/route", () => {
    it("returns 400 if missing parameters", async () => {
      const response = await getRoute(req("http://localhost/api/route"));
      expect(response.status).toBe(400);
    });

    it("returns 400 if coordinates out of bounds", async () => {
      const response = await getRoute(req(`http://localhost/api/route?fromLng=999&fromLat=40.74&toRoomId=${TEST_ROOM_ID}`));
      expect(response.status).toBe(400);
    });

    it("returns 404 if no nearest room found", async () => {
      mockGetNearestRoom.mockResolvedValueOnce(null);
      const response = await getRoute(req(`http://localhost/api/route?fromLng=-73.98&fromLat=40.74&toRoomId=${TEST_ROOM_ID}`));
      expect(response.status).toBe(404);
    });

    it("returns 200 with route if nearest room is found", async () => {
      mockGetNearestRoom.mockResolvedValueOnce({ id: "123e4567-e89b-12d3-a456-426614174000", building_id: "123e4567-e89b-12d3-a456-426614174001", floor: "1", name: "Lobby", geom: null });
      mockFindShortestPath.mockResolvedValueOnce({
        type: "Feature",
        properties: { distance_meters: 10 },
        geometry: { type: "LineString", coordinates: [[0, 0], [1, 1]] },
      });
      const response = await getRoute(req(`http://localhost/api/route?fromLng=-73.98&fromLat=40.74&toRoomId=${TEST_ROOM_ID}`));

      expect(response.status).toBe(200);
      const json = await response.json();
      expect(json.data.type).toBe("Feature");
    });

    it("returns 404 if no route found", async () => {
      mockGetNearestRoom.mockResolvedValueOnce({ id: "123e4567-e89b-12d3-a456-426614174000", building_id: "123e4567-e89b-12d3-a456-426614174001", floor: "1", name: "Lobby", geom: null });
      mockFindShortestPath.mockResolvedValueOnce(null);
      const response = await getRoute(req(`http://localhost/api/route?fromLng=-73.98&fromLat=40.74&toRoomId=${TEST_ROOM_ID}`));
      expect(response.status).toBe(404);
    });

    it("handles internal errors", async () => {
      mockGetNearestRoom.mockRejectedValueOnce(new Error("KNN crash"));
      const response = await getRoute(req(`http://localhost/api/route?fromLng=-73.98&fromLat=40.74&toRoomId=${TEST_ROOM_ID}`));
      expect(response.status).toBe(500);
    });

    it("accepts accessible parameter", async () => {
      mockGetNearestRoom.mockResolvedValueOnce({ id: "123e4567-e89b-12d3-a456-426614174000", building_id: "123e4567-e89b-12d3-a456-426614174001", floor: "1", name: "Lobby", geom: null });
      mockFindShortestPath.mockResolvedValueOnce({
        type: "Feature",
        properties: { distance_meters: 10 },
        geometry: { type: "LineString", coordinates: [[0, 0], [1, 1]] },
      });
      const response = await getRoute(req(`http://localhost/api/route?fromLng=-73.98&fromLat=40.74&toRoomId=${TEST_ROOM_ID}&accessible=true`));
      expect(response.status).toBe(200);
    });
  });
});
