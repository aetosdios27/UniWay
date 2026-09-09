import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import { QgisDatasetSchema } from "@/lib/spatial/qgis";
import { fetchNodeEdges, fetchRoutingNodes } from "@/lib/spatial/nodes";
import { buildNodeGraph, findNodeRoute, routeOnNodeGraph } from "./nodes";

vi.mock("@/lib/spatial/nodes", () => ({ fetchNodeEdges: vi.fn(), fetchRoutingNodes: vi.fn() }));
const read = (name: string) => JSON.parse(readFileSync(`data/muj/${name}.geojson`, "utf8"));
const data = QgisDatasetSchema.parse({ nodes: read("nodes"), edges: read("edges"), destinations: read("destinations") });
const campusId = "11111111-1111-4111-8111-111111111111";
const nodes = data.nodes.features.map(f => ({ ...f.properties, campus_id: campusId, geom: f.geometry }));
const edges = data.edges.features.map(f => ({ ...f.properties, geom: f.geometry }));

describe("node routing", () => {
  it("routes between all supplied destinations using real geometry", () => {
    const graph = buildNodeGraph(nodes, edges, false);
    for (const from of data.destinations.features) {
      for (const to of data.destinations.features) {
        const route = routeOnNodeGraph(graph, from.properties.routing_node_id, to.properties.routing_node_id);
        expect(route).not.toBeNull();
        expect(route!.geometry.coordinates.length).toBeGreaterThanOrEqual(2);
      }
    }
  });

  it("preserves a curved edge, reverses it, and chooses the cheaper parallel edge", () => {
    const edge = edges.find(e => e.geom.type === "LineString" && e.geom.coordinates.length > 2)!;
    const expensive = { ...edge, edge_id: "longer", distance_meters: edge.distance_meters + 100 };
    const graph = buildNodeGraph(nodes, [expensive, edge], false);
    expect(routeOnNodeGraph(graph, edge.source_node_id, edge.target_node_id)).toMatchObject({
      properties: { distance_meters: edge.distance_meters }, geometry: edge.geom,
    });
    expect(routeOnNodeGraph(graph, edge.target_node_id, edge.source_node_id)!.geometry.coordinates)
      .toEqual([...edge.geom.coordinates].reverse());
  });

  it("retains the Point edge and its exact declared distance", () => {
    const edge = edges.find(e => e.edge_id === "E00143")!;
    const graph = buildNodeGraph(nodes, [edge], false);
    expect(routeOnNodeGraph(graph, edge.source_node_id, edge.target_node_id)).toEqual({
      type: "Feature", properties: { distance_meters: edge.distance_meters },
      geometry: { type: "LineString", coordinates: [edge.geom.coordinates, edge.geom.coordinates] },
    });
    expect(edge.geom.type).toBe("Point");
  });

  it("returns null for unknown or disconnected nodes, but supports a same-node route", () => {
    const graph = buildNodeGraph(nodes, edges, false);
    expect(routeOnNodeGraph(graph, "missing", nodes[0].node_id)).toBeNull();
    expect(routeOnNodeGraph(graph, nodes[0].node_id, "OUT_AB3_0_114")).toBeNull();
    const route = routeOnNodeGraph(graph, nodes[0].node_id, nodes[0].node_id)!;
    expect(route.properties.distance_meters).toBe(0);
    expect(route.geometry.coordinates).toEqual([nodes[0].geom.coordinates, nodes[0].geom.coordinates]);
  });

  it("filters inaccessible nodes and edges before choosing parallel edges", () => {
    const edge = edges[0];
    const blocked = { ...edge, is_accessible: false };
    const accessible = { ...edge, edge_id: "accessible", distance_meters: edge.distance_meters + 20 };
    const graph = buildNodeGraph(nodes, [blocked, accessible], true);
    expect(routeOnNodeGraph(graph, edge.source_node_id, edge.target_node_id)!.properties.distance_meters)
      .toBe(accessible.distance_meters);
    const filteredNodes = nodes.map(n => ({ ...n, is_accessible: n.node_id !== edge.target_node_id }));
    expect(routeOnNodeGraph(buildNodeGraph(filteredNodes, [edge], true), edge.source_node_id, edge.target_node_id)).toBeNull();
  });

  it("loads only the requested campus and does not reuse stale routes", async () => {
    vi.mocked(fetchRoutingNodes).mockResolvedValue(nodes);
    vi.mocked(fetchNodeEdges).mockResolvedValueOnce(edges).mockResolvedValueOnce([]);
    expect(await findNodeRoute(campusId, edges[0].source_node_id, edges[0].target_node_id, false)).not.toBeNull();
    expect(await findNodeRoute(campusId, edges[0].source_node_id, edges[0].target_node_id, false)).toBeNull();
    expect(fetchRoutingNodes).toHaveBeenCalledWith(campusId);
    expect(fetchNodeEdges).toHaveBeenCalledWith(campusId);
  });
});
