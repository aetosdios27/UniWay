import { z } from "zod";
import { PoiIconKeySchema } from "@/lib/poi-icons";
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
    category: z.string().min(1).nullable().optional().transform(v => v ?? null),
    icon_key: PoiIconKeySchema.nullable().optional().transform(v => v ?? null),
    tags: z.array(z.string()).nullish().transform(v => v ?? []),
  }),
  geometry: RoutingPointSchema,
});

export const PoiFeatureSchema = z.object({
  type: z.literal("Feature"),
  properties: z.object({
    id: z.string().min(1),
    name: z.string().min(1),
    category: z.string().min(1),
    icon_key: PoiIconKeySchema.nullable().optional().transform(v => v ?? null),
    tags: z.array(z.string()).nullish().transform(v => v ?? []),
    routing_node_id: RoutingNodeIdSchema.nullable().optional().transform(v => v ?? null),
  }),
  geometry: RoutingPointSchema,
});
export type PoiFeature = z.infer<typeof PoiFeatureSchema>;

export const PoiFeatureCollectionSchema = z.object({
  type: z.literal("FeatureCollection"),
  features: z.array(PoiFeatureSchema),
});
export type PoiFeatureCollection = z.infer<typeof PoiFeatureCollectionSchema>;

export const QgisDatasetSchema = z.object({
  nodes: RoutingNodesFileSchema,
  edges: z.object({ type: z.literal("FeatureCollection"), features: z.array(EdgeFeatureSchema).min(1) }),
  destinations: z.object({ type: z.literal("FeatureCollection"), features: z.array(DestinationFeatureSchema).min(1) }),
  pois: PoiFeatureCollectionSchema.optional(),
});
export type QgisDataset = z.infer<typeof QgisDatasetSchema>;

export interface SequentialNidResult {
  minNid: number;
  maxNid: number;
  count: number;
  expectedCount: number;
  /** Total distinct missing NIDs; equals expectedCount - count. */
  missingCount: number;
  /** First MIN_REPORTED_MISSING entries of missingCount; the rest stay unenumerated. */
  missingNids: number[];
  isSequential: boolean;
}

/** Cap on the reported missing list, so a huge NID gap cannot exhaust memory. */
const MAX_REPORTED_MISSING = 100;

/**
 * Verifies that all NIDs between min(NID) and max(NID) are present without gaps.
 *
 * One set pass is O(N). The sequential/increment test is answered from
 * `missingCount` alone, so gap-free datasets never enumerate anything; the
 * sorted scan only runs on the failure path and visits each reported gap
 * once, instead of probing every integer between min and max.
 */
export function checkSequentialNids(nids: number[]): SequentialNidResult {
  if (nids.length === 0) {
    return {
      minNid: 0,
      maxNid: 0,
      count: 0,
      expectedCount: 0,
      missingCount: 0,
      missingNids: [],
      isSequential: true,
    };
  }

  const unique = [...new Set(nids)].sort((a, b) => a - b);
  const minNid = unique[0];
  const maxNid = unique[unique.length - 1];
  const expectedCount = maxNid - minNid + 1;
  const missingCount = expectedCount - unique.length;

  const missingNids: number[] = [];
  if (missingCount > 0) {
    let expected = minNid;
    for (const value of unique) {
      if (missingNids.length >= MAX_REPORTED_MISSING) break;
      for (let gap = expected; gap < value && missingNids.length < MAX_REPORTED_MISSING; gap++) {
        missingNids.push(gap);
      }
      expected = value + 1;
    }
  }

  return {
    minNid,
    maxNid,
    count: unique.length,
    expectedCount,
    missingCount,
    missingNids,
    isSequential: missingCount === 0,
  };
}

/**
 * Validates that node_id follows canonical convention:
 * OUT_<loc>_<floor_id>_<3+ digit zero-padded nid>
 */
export function checkNodeNames(features: QgisDataset["nodes"]["features"]): string[] {
  const errors: string[] = [];
  for (const node of features) {
    const p = node.properties;
    const padded = String(p.nid).padStart(3, "0");
    const expectedId = `OUT_${p.loc}_${p.floor_id}_${padded}`;
    if (p.node_id !== expectedId) {
      errors.push(
        `Node name mismatch: node has id '${p.node_id}', but properties (loc: '${p.loc}', floor_id: '${p.floor_id}', nid: ${p.nid}) require '${expectedId}'`
      );
    }
  }
  return errors;
}

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

function missingNidsError(sequence: SequentialNidResult): string {
  const listed = sequence.missingNids.join(", ");
  const remainder = sequence.missingCount - sequence.missingNids.length;
  return remainder > 0
    ? `Missing sequential NIDs between ${sequence.minNid} and ${sequence.maxNid}: ${listed}, and ${remainder} more`
    : `Missing sequential NIDs between ${sequence.minNid} and ${sequence.maxNid}: ${listed}`;
}

export function validateQgisDataset(data: QgisDataset) {
  const nodes = new Map(data.nodes.features.map(f => [f.properties.node_id, f.geometry.coordinates]));
  const adjacency = new Map([...nodes.keys()].map(id => [id, new Set<string>()]));
  const warnings = duplicateLocations(data);
  const nids = data.nodes.features.map(f => f.properties.nid);
  const nidSequence = checkSequentialNids(nids);

  const errors = [
    ...duplicateIds(data.nodes.features.map(f => f.properties.node_id), "node_id"),
    ...duplicateIds(nids, "nid"),
    ...duplicateIds(data.edges.features.map(f => f.properties.edge_id), "edge_id"),
    ...duplicateIds(data.destinations.features.map(f => f.properties.id), "destination id"),
    ...(data.pois ? duplicateIds(data.pois.features.map(f => f.properties.id), "poi id") : []),
    ...checkNodeNames(data.nodes.features),
    ...(!nidSequence.isSequential ? [missingNidsError(nidSequence)] : []),
    ...checkEdges(data, nodes, adjacency, warnings),
  ];
  for (const destination of data.destinations.features) {
    if (!nodes.has(destination.properties.routing_node_id)) {
      errors.push(`Destination ${destination.properties.id} references a missing node`);
    }
  }
  if (data.pois) {
    for (const poi of data.pois.features) {
      if (poi.properties.routing_node_id && !nodes.has(poi.properties.routing_node_id)) {
        errors.push(`POI ${poi.properties.id} references a missing node`);
      }
    }
  }
  const groups = components(adjacency);
  if (groups.length > 1) warnings.push(`Disconnected components: ${groups.map(g => g.length).join(", ")} nodes`);

  return {
    errors,
    warnings,
    components: groups,
    stats: {
      totalNodes: data.nodes.features.length,
      minNid: nidSequence.minNid,
      maxNid: nidSequence.maxNid,
      missingNids: nidSequence.missingNids,
      totalEdges: data.edges.features.length,
      totalDestinations: data.destinations.features.length,
      totalPois: data.pois?.features.length ?? 0,
    },
  };
}
