import { z } from "zod";
import { sql } from "@/lib/db";
import { RoutingNodeSchema } from "@/lib/schemas/db";
import { DestinationFeatureSchema, EdgeFeatureSchema } from "@/lib/spatial/qgis";

export const NodeEdgeSchema = EdgeFeatureSchema.shape.properties.extend({ geom: EdgeFeatureSchema.shape.geometry });
export type NodeEdge = z.infer<typeof NodeEdgeSchema>;
const DestinationSchema = DestinationFeatureSchema.shape.properties.extend({ geom: DestinationFeatureSchema.shape.geometry });

export async function fetchRoutingNodes(campusId: string) {
  const rows = await sql`
    SELECT campus_id, node_id, nid, loc, node_type, floor_id, is_accessible, ST_AsGeoJSON(geom, 15)::json AS geom
    FROM routing_nodes WHERE campus_id = ${campusId}
  `;
  return z.array(RoutingNodeSchema).parse(rows);
}

export async function fetchNodeEdges(campusId: string) {
  const rows = await sql`
    SELECT edge_id, source_node_id, target_node_id, distance_meters, is_accessible, floor_id, edge_type,
      ST_AsGeoJSON(geom, 15)::json AS geom
    FROM routing_node_edges WHERE campus_id = ${campusId}
  `;
  return z.array(NodeEdgeSchema).parse(rows);
}

export async function fetchRoutingDestinations(campusId: string) {
  const rows = await sql`
    SELECT id, name, type, routing_node_id, ST_AsGeoJSON(geom, 15)::json AS geom
    FROM routing_destinations WHERE campus_id = ${campusId} ORDER BY name, id
  `;
  return z.array(DestinationSchema).parse(rows);
}

export async function getNearestRoutingNode(campusId: string, lng: number, lat: number, floor: string, accessible: boolean) {
  const rows = await sql`
    SELECT campus_id, node_id, nid, loc, node_type, floor_id, is_accessible, ST_AsGeoJSON(geom, 15)::json AS geom
    FROM routing_nodes
    WHERE campus_id = ${campusId} AND floor_id = ${floor}
      AND (NOT ${accessible} OR is_accessible)
      AND ST_DWithin(geom::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography, 50)
    ORDER BY ST_Distance(geom::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography), node_id
    LIMIT 1
  `;
  return rows.length ? RoutingNodeSchema.parse(rows[0]) : null;
}
