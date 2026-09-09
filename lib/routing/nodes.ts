import { UndirectedGraph } from "graphology";
import { dijkstra } from "graphology-shortest-path";
import type { RoutingNode } from "@/lib/schemas/db";
import { fetchNodeEdges, fetchRoutingNodes, type NodeEdge } from "@/lib/spatial/nodes";
import type { GeoJSONLineStringFeature } from "./route-assembly";

function addUsableEdge(graph: UndirectedGraph, edge: NodeEdge) {
  if (!graph.hasNode(edge.source_node_id) || !graph.hasNode(edge.target_node_id)) return;
  if (graph.hasEdge(edge.source_node_id, edge.target_node_id)) return;
  graph.addEdgeWithKey(edge.edge_id, edge.source_node_id, edge.target_node_id, edge);
}

export function buildNodeGraph(nodes: RoutingNode[], edges: NodeEdge[], accessible: boolean) {
  const graph = new UndirectedGraph();
  for (const node of nodes.filter(n => !accessible || n.is_accessible)) {
    graph.addNode(node.node_id, { coordinates: node.geom.coordinates });
  }
  // Cheapest usable parallel edge wins, irrespective of database row order.
  const usableEdges = edges.filter(e => !accessible || e.is_accessible)
    .sort((a, b) => a.distance_meters - b.distance_meters || a.edge_id.localeCompare(b.edge_id));
  for (const edge of usableEdges) {
    addUsableEdge(graph, edge);
  }
  return graph;
}

function edgeCoordinates(edge: NodeEdge, from: string): [number, number][] {
  if (edge.geom.type === "Point") return [edge.geom.coordinates];
  if (edge.source_node_id === from) return edge.geom.coordinates;
  return [...edge.geom.coordinates].reverse();
}

export function routeOnNodeGraph(graph: UndirectedGraph, from: string, to: string): GeoJSONLineStringFeature | null {
  if (!graph.hasNode(from) || !graph.hasNode(to)) return null;
  const path = dijkstra.bidirectional(graph, from, to, "distance_meters");
  if (!path) return null;
  return assembleNodePath(graph, path);
}

function assembleNodePath(graph: UndirectedGraph, path: string[]): GeoJSONLineStringFeature {
  let distance = 0;
  const coordinates: [number, number][] = [];
  for (let i = 1; i < path.length; i++) {
    const edge = graph.getEdgeAttributes(graph.edge(path[i - 1], path[i])) as NodeEdge;
    distance += edge.distance_meters;
    coordinates.push(...edgeCoordinates(edge, path[i - 1]));
  }
  if (!coordinates.length) coordinates.push(graph.getNodeAttribute(path[0], "coordinates"));
  if (coordinates.length === 1) coordinates.push([...coordinates[0]]);
  return { type: "Feature", properties: { distance_meters: distance }, geometry: { type: "LineString", coordinates } };
}

export async function findNodeRoute(campusId: string, from: string, to: string, accessible: boolean) {
  // ponytail: reload this small campus graph per request; add versioned caching only if measured latency requires it.
  const [nodes, edges] = await Promise.all([fetchRoutingNodes(campusId), fetchNodeEdges(campusId)]);
  return routeOnNodeGraph(buildNodeGraph(nodes, edges, accessible), from, to);
}
