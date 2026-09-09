import { z } from "zod";
import { sql } from "@/lib/db";
import { QgisDatasetSchema, validateQgisDataset } from "@/lib/spatial/qgis";

/** Upsert a complete export without deleting records absent from subsequent exports. */
export async function importQgisDataset(campusId: string, input: unknown) {
  z.string().uuid().parse(campusId);
  const data = QgisDatasetSchema.parse(input);
  const { errors, warnings } = validateQgisDataset(data);
  if (errors.length) throw new Error(errors.join("\n"));

  await sql.begin(async tx => {
    // Serialize imports to the same campus; unknown campus IDs never create demo data.
    const campus = await tx`SELECT id FROM campuses WHERE id = ${campusId} FOR UPDATE`;
    if (!campus.length) throw new Error(`Campus ${campusId} does not exist`);

    await tx`
      INSERT INTO routing_nodes (campus_id, node_id, nid, loc, node_type, floor_id, is_accessible, geom)
      SELECT ${campusId}, p->>'node_id', (p->>'nid')::integer, p->>'loc', p->>'node_type',
        p->>'floor_id', (p->>'is_accessible')::boolean, ST_SetSRID(ST_GeomFromGeoJSON(f->>'geometry'), 4326)
      FROM jsonb_array_elements(${JSON.stringify(data.nodes.features)}::text::jsonb) f,
        LATERAL (SELECT f->'properties' AS p) props
      ON CONFLICT (campus_id, node_id) DO UPDATE SET
        nid = EXCLUDED.nid, loc = EXCLUDED.loc, node_type = EXCLUDED.node_type,
        floor_id = EXCLUDED.floor_id, is_accessible = EXCLUDED.is_accessible, geom = EXCLUDED.geom
    `;
    await tx`
      INSERT INTO routing_node_edges
        (campus_id, edge_id, source_node_id, target_node_id, distance_meters, is_accessible, floor_id, edge_type, geom)
      SELECT ${campusId}, p->>'edge_id', p->>'source_node_id', p->>'target_node_id',
        (p->>'distance_meters')::float8, (p->>'is_accessible')::boolean, p->>'floor_id', p->>'edge_type',
        ST_SetSRID(ST_GeomFromGeoJSON(f->>'geometry'), 4326)
      FROM jsonb_array_elements(${JSON.stringify(data.edges.features)}::text::jsonb) f,
        LATERAL (SELECT f->'properties' AS p) props
      ON CONFLICT (campus_id, edge_id) DO UPDATE SET
        source_node_id = EXCLUDED.source_node_id, target_node_id = EXCLUDED.target_node_id,
        distance_meters = EXCLUDED.distance_meters, is_accessible = EXCLUDED.is_accessible,
        floor_id = EXCLUDED.floor_id, edge_type = EXCLUDED.edge_type, geom = EXCLUDED.geom
    `;
    await tx`
      INSERT INTO routing_destinations (campus_id, id, name, type, routing_node_id, geom)
      SELECT ${campusId}, p->>'id', p->>'name', p->>'type', p->>'routing_node_id',
        ST_SetSRID(ST_GeomFromGeoJSON(f->>'geometry'), 4326)
      FROM jsonb_array_elements(${JSON.stringify(data.destinations.features)}::text::jsonb) f,
        LATERAL (SELECT f->'properties' AS p) props
      ON CONFLICT (campus_id, id) DO UPDATE SET
        name = EXCLUDED.name, type = EXCLUDED.type, routing_node_id = EXCLUDED.routing_node_id, geom = EXCLUDED.geom
    `;
  });
  return { campusId, nodes: data.nodes.features.length, edges: data.edges.features.length,
    destinations: data.destinations.features.length, warnings };
}
