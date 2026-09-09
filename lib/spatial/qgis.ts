import { z } from "zod";
import { RoutingLineStringSchema, RoutingNodeIdSchema, RoutingNodesFileSchema, RoutingPointSchema } from "@/lib/schemas/db";

export const EdgeFeatureSchema = z.object({
  type: z.literal("Feature"),
  properties: z.object({
    edge_id: z.string().min(1),
    source_node_id: RoutingNodeIdSchema,
    target_node_id: RoutingNodeIdSchema,
    distance_meters: z.number().finite().positive(),
    is_accessible: z.boolean(),
    floor_id: z.string().min(1),
    edge_type: z.enum(["walkway", "corridor", "stairs", "elevator", "door"]),
  }),
  // ponytail: preserve collapsed QGIS edges as Points until the source export is corrected.
  geometry: z.union([RoutingLineStringSchema, RoutingPointSchema]),
});

export const DestinationFeatureSchema = z.object({
  type: z.literal("Feature"),
  properties: z.object({
    id: z.string().min(1),
    name: z.string().min(1),
    type: z.literal("destination"),
    routing_node_id: RoutingNodeIdSchema,
  }),
  geometry: RoutingPointSchema,
});

export const QgisDatasetSchema = z.object({
  nodes: RoutingNodesFileSchema,
  edges: z.object({ type: z.literal("FeatureCollection"), features: z.array(EdgeFeatureSchema).min(1) }),
  destinations: z.object({ type: z.literal("FeatureCollection"), features: z.array(DestinationFeatureSchema).min(1) }),
});
export type QgisDataset = z.infer<typeof QgisDatasetSchema>;

function duplicateIds(ids: (string | number)[], label: string): string[] {
  const seen = new Set<string | number>();
  return ids.flatMap(id => {
    if (seen.has(id)) return [`Duplicate ${label}: ${id}`];
    seen.add(id);
    return [];
  });
}

function component(start: string, remaining: Set<string>, adjacency: Map<string, Set<string>>): string[] {
  const queue = [start];
  const ids: string[] = [];
  remaining.delete(start);
  while (queue.length) {
    const id = queue.pop()!;
    ids.push(id);
    for (const next of adjacency.get(id)!) {
      if (remaining.delete(next)) queue.push(next);
    }
  }
  return ids;
}

function components(adjacency: Map<string, Set<string>>): string[][] {
  const remaining = new Set(adjacency.keys());
  const result: string[][] = [];
  while (remaining.size) result.push(component(remaining.values().next().value!, remaining, adjacency));
  return result;
}

function samePoint(a: number[], b: number[]): boolean {
  return Math.hypot(a[0] - b[0], a[1] - b[1]) <= 0.000001;
}

function checkEdgeGeometry(edge: QgisDataset["edges"]["features"][number], source: number[], target: number[], warnings: string[]): string[] {
  if (edge.geometry.type === "Point") {
    warnings.push(`Edge ${edge.properties.edge_id} has Point geometry; retained unchanged`);
    return [];
  }
  const coords = edge.geometry.coordinates;
  if (!samePoint(source, coords[0]) || !samePoint(target, coords[coords.length - 1])) {
    return [`Edge ${edge.properties.edge_id} geometry does not run from source to target`];
  }
  return [];
}

function checkEdges(data: QgisDataset, nodes: Map<string, number[]>, adjacency: Map<string, Set<string>>, warnings: string[]): string[] {
  const errors: string[] = [];
  for (const edge of data.edges.features) {
    const p = edge.properties;
    const source = nodes.get(p.source_node_id);
    const target = nodes.get(p.target_node_id);
    if (!source || !target) {
      errors.push(`Edge ${p.edge_id} references a missing node`);
      continue;
    }
    adjacency.get(p.source_node_id)!.add(p.target_node_id);
    adjacency.get(p.target_node_id)!.add(p.source_node_id);
    errors.push(...checkEdgeGeometry(edge, source, target, warnings));
  }
  return errors;
}

function duplicateLocations(data: QgisDataset): string[] {
  const seen = new Map<string, string>();
  const warnings: string[] = [];
  for (const node of data.nodes.features) {
    const key = JSON.stringify([node.properties.floor_id, node.geometry.coordinates]);
    const previous = seen.get(key);
    if (previous) warnings.push(`Shared location: ${previous}, ${node.properties.node_id}`);
    seen.set(key, node.properties.node_id);
  }
  return warnings;
}

export function validateQgisDataset(data: QgisDataset) {
  const nodes = new Map(data.nodes.features.map(f => [f.properties.node_id, f.geometry.coordinates]));
  const adjacency = new Map([...nodes.keys()].map(id => [id, new Set<string>()]));
  const warnings = duplicateLocations(data);
  const errors = [
    ...duplicateIds(data.nodes.features.map(f => f.properties.node_id), "node_id"),
    ...duplicateIds(data.nodes.features.map(f => f.properties.nid), "nid"),
    ...duplicateIds(data.edges.features.map(f => f.properties.edge_id), "edge_id"),
    ...duplicateIds(data.destinations.features.map(f => f.properties.id), "destination id"),
    ...checkEdges(data, nodes, adjacency, warnings),
  ];
  for (const destination of data.destinations.features) {
    if (!nodes.has(destination.properties.routing_node_id)) {
      errors.push(`Destination ${destination.properties.id} references a missing node`);
    }
  }
  const groups = components(adjacency);
  if (groups.length > 1) warnings.push(`Disconnected components: ${groups.map(g => g.length).join(", ")} nodes`);
  return { errors, warnings, components: groups };
}
