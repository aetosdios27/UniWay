import { UndirectedGraph } from "graphology";
import { dijkstra } from "graphology-shortest-path";
import { fetchEdgesFromCampus } from "@/lib/spatial/edges";
import { fetchRoomCentroidsForCampus, getCampusIdForRoom } from "@/lib/spatial/rooms";
import { assembleRoute, type GeoJSONLineStringFeature } from "./route-assembly";
import type { RoutingEdge } from "@/lib/schemas/db";

export function buildGraph(edges: RoutingEdge[], accessibilityRequired: boolean): UndirectedGraph {
  const graph = new UndirectedGraph();

  for (const edge of edges) {
    if (accessibilityRequired && !edge.is_accessible) {
      continue;
    }

    const { source_node_id, target_node_id, distance_meters } = edge;

    if (!graph.hasNode(source_node_id)) {
      graph.addNode(source_node_id);
    }
    if (!graph.hasNode(target_node_id)) {
      graph.addNode(target_node_id);
    }

    if (!graph.hasEdge(source_node_id, target_node_id)) {
      graph.addEdge(source_node_id, target_node_id, { distance_meters });
    }
  }

  return graph;
}

export async function findShortestPath(
  startRoomId: string,
  toRoomId: string,
  accessible: boolean
): Promise<GeoJSONLineStringFeature | null> {
  // ponytail: read current obstructions each request; use shared versioned caching only if routing latency requires it.
  const campusId = await getCampusIdForRoom(startRoomId);
  if (!campusId) {
    return null;
  }

  const [edges, coordMap] = await Promise.all([
    fetchEdgesFromCampus(campusId),
    fetchRoomCentroidsForCampus(campusId)
  ]);

  const graph = buildGraph(edges, accessible);

  if (startRoomId === toRoomId) {
    return assembleRoute([startRoomId], coordMap, 0);
  }

  return routeFromGraph(graph, startRoomId, toRoomId, coordMap);
}

function routeFromGraph(graph: UndirectedGraph, startRoomId: string, toRoomId: string, coordMap: Map<string, [number, number]>) {
  if (!graph.hasNode(startRoomId) || !graph.hasNode(toRoomId)) {
    return null;
  }

  const path = dijkstra.bidirectional(graph, startRoomId, toRoomId, "distance_meters");
  if (!path) {
    return null;
  }

  const totalDistance = path.slice(1).reduce((sum, node, index) =>
    sum + graph.getEdgeAttribute(path[index], node, "distance_meters"), 0);
  return assembleRoute(path, coordMap, totalDistance);
}
