import { describe, it, expect, vi, beforeEach } from "vitest";
import { buildGraph, findShortestPath } from "./graph";
import { sql } from "@/lib/db";
import { fetchEdgesFromCampus } from "@/lib/spatial/edges";
import type { RoutingEdge } from "@/lib/schemas/db";

// Mock dependencies
vi.mock("@/lib/db", () => {
  const sqlMock = vi.fn();
  return { sql: sqlMock };
});

vi.mock("@/lib/spatial/edges", () => ({
  fetchEdgesFromCampus: vi.fn(),
}));

describe("Graph routing engine", () => {
  const mockEdges: RoutingEdge[] = [
    {
      id: "edge-1",
      source_node_id: "room-a",
      target_node_id: "room-b",
      distance_meters: 10,
      is_accessible: true,
      floor_id: "1",
    },
    {
      id: "edge-2",
      source_node_id: "room-b",
      target_node_id: "room-c",
      distance_meters: 5,
      is_accessible: false, // stair/inaccessible
      floor_id: "1",
    },
    {
      id: "edge-3",
      source_node_id: "room-a",
      target_node_id: "room-c",
      distance_meters: 20,
      is_accessible: true,
      floor_id: "1",
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("buildGraph", () => {
    it("should build undirected graph containing all nodes and edges", () => {
      const graph = buildGraph(mockEdges, false);

      expect(graph.order).toBe(3); // A, B, C
      expect(graph.size).toBe(3); // 3 edges
      expect(graph.hasNode("room-a")).toBe(true);
      expect(graph.hasNode("room-b")).toBe(true);
      expect(graph.hasNode("room-c")).toBe(true);
      expect(graph.getEdgeAttribute("room-a", "room-b", "distance_meters")).toBe(10);
    });

    it("should drop inaccessible edges if accessibilityRequired is true", () => {
      const graph = buildGraph(mockEdges, true);

      expect(graph.order).toBe(3); // Nodes are still added by accessible edges
      expect(graph.size).toBe(2); // edge-2 (inaccessible) is dropped
      expect(graph.hasEdge("room-b", "room-c")).toBe(false);
      expect(graph.hasEdge("room-a", "room-b")).toBe(true);
      expect(graph.hasEdge("room-a", "room-c")).toBe(true);
    });
  });

  describe("findShortestPath", () => {
    const mockCampusId = "campus-123";

    beforeEach(() => {
      // Mock the getCampusIdForRoom query
      (sql as unknown as ReturnType<typeof vi.fn>).mockImplementation(async (strings) => {
        const query = strings ? strings.join("") : "";
        if (query.includes("centroid")) {
          return [
            { id: "room-a", centroid: { coordinates: [-73.985, 40.748] } },
            { id: "room-b", centroid: { coordinates: [-73.984, 40.749] } },
            { id: "room-c", centroid: { coordinates: [-73.983, 40.750] } },
          ];
        }
        if (query.includes("campus_id")) {
          return [{ campus_id: mockCampusId }];
        }
        return [];
      });

      // Mock fetchEdgesFromCampus
      (fetchEdgesFromCampus as unknown as ReturnType<typeof vi.fn>).mockResolvedValue(mockEdges);
    });

    it("should find the shortest path and return GeoJSON line feature", async () => {
      const result = await findShortestPath("room-a", "room-c", false);

      expect(result).not.toBeNull();
      expect(result?.properties.distance_meters).toBe(15); // room-a -> room-b -> room-c (10 + 5)
      expect(result?.geometry.coordinates).toEqual([
        [-73.985, 40.748], // room-a
        [-73.984, 40.749], // room-b
        [-73.983, 40.750], // room-c
      ]);
    });

    it("should route around inaccessible edges if accessible flag is true", async () => {
      const result = await findShortestPath("room-a", "room-c", true);

      expect(result).not.toBeNull();
      // Must take the direct but longer path (room-a -> room-c) of 20 meters, because the (a->b->c) route has an inaccessible edge
      expect(result?.properties.distance_meters).toBe(20);
      expect(result?.geometry.coordinates).toEqual([
        [-73.985, 40.748],
        [-73.983, 40.750],
      ]);
    });

    it("should return early with single-point path if start and destination are identical", async () => {
      const result = await findShortestPath("room-a", "room-a", false);

      expect(result).not.toBeNull();
      expect(result?.properties.distance_meters).toBe(0);
      expect(result?.geometry.coordinates).toEqual([
        [-73.985, 40.748],
        [-73.985, 40.748],
      ]);
    });

    it("reloads edges after an obstruction opens or resolves", async () => {
      const res1 = await findShortestPath("room-a", "room-c", false);
      expect(res1?.properties.distance_meters).toBe(15);
      vi.mocked(fetchEdgesFromCampus).mockResolvedValueOnce([mockEdges[2]]);
      const res2 = await findShortestPath("room-a", "room-c", false);
      expect(res2?.properties.distance_meters).toBe(20);
      const res3 = await findShortestPath("room-a", "room-c", false);
      expect(res3?.properties.distance_meters).toBe(15);
      expect(fetchEdgesFromCampus).toHaveBeenCalledTimes(3);
    });

    it("should return null if start room campus is not found", async () => {
      // Override mock to return no campus
      (sql as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce([]);

      const result = await findShortestPath("room-unknown", "room-c", false);
      expect(result).toBeNull();
    });

    it("should return null if there is no path between the rooms", async () => {
      // Mock edges where there is no connection to room-c
      const disconnectedEdges: RoutingEdge[] = [
        {
          id: "edge-1",
          source_node_id: "room-a",
          target_node_id: "room-b",
          distance_meters: 10,
          is_accessible: true,
          floor_id: "1",
        },
      ];
      (fetchEdgesFromCampus as unknown as ReturnType<typeof vi.fn>).mockResolvedValue(disconnectedEdges);

      const result = await findShortestPath("room-a", "room-c", false);
      expect(result).toBeNull();
    });

    it("should return null if starting node is not in graph and not same as destination", async () => {
      const result = await findShortestPath("room-x", "room-c", false);
      expect(result).toBeNull();
    });
  });
});
