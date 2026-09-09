// Ley wraps migrations in a transaction. Legacy room-based edges stay untouched.
export async function up(sql) {
  await sql`
    CREATE TABLE routing_node_edges (
      campus_id UUID NOT NULL REFERENCES campuses(id) ON DELETE CASCADE,
      edge_id TEXT NOT NULL CHECK (length(edge_id) > 0),
      source_node_id TEXT NOT NULL,
      target_node_id TEXT NOT NULL,
      distance_meters DOUBLE PRECISION NOT NULL
        CHECK (distance_meters > 0 AND distance_meters < 'Infinity'::float8),
      is_accessible BOOLEAN NOT NULL,
      floor_id TEXT NOT NULL CHECK (length(floor_id) > 0),
      edge_type TEXT NOT NULL CHECK (edge_type IN ('walkway', 'corridor', 'stairs', 'elevator', 'door')),
      geom GEOMETRY(Geometry, 4326) NOT NULL,
      PRIMARY KEY (campus_id, edge_id),
      FOREIGN KEY (campus_id, source_node_id) REFERENCES routing_nodes(campus_id, node_id),
      FOREIGN KEY (campus_id, target_node_id) REFERENCES routing_nodes(campus_id, node_id),
      CHECK (GeometryType(geom) IN ('POINT', 'LINESTRING') AND NOT ST_IsEmpty(geom))
    )
  `;
  await sql`CREATE INDEX routing_node_edges_source_idx ON routing_node_edges (campus_id, source_node_id)`;
  await sql`CREATE INDEX routing_node_edges_target_idx ON routing_node_edges (campus_id, target_node_id)`;
  await sql`CREATE INDEX routing_node_edges_geom_idx ON routing_node_edges USING GIST (geom)`;
  await sql`
    CREATE TABLE routing_destinations (
      campus_id UUID NOT NULL REFERENCES campuses(id) ON DELETE CASCADE,
      id TEXT NOT NULL CHECK (length(id) > 0),
      name TEXT NOT NULL CHECK (length(name) > 0),
      type TEXT NOT NULL CHECK (type = 'destination'),
      routing_node_id TEXT NOT NULL,
      geom GEOMETRY(Point, 4326) NOT NULL CHECK (NOT ST_IsEmpty(geom)),
      PRIMARY KEY (campus_id, id),
      FOREIGN KEY (campus_id, routing_node_id) REFERENCES routing_nodes(campus_id, node_id)
    )
  `;
  await sql`CREATE INDEX routing_destinations_node_idx ON routing_destinations (campus_id, routing_node_id)`;
}

export async function down(sql) {
  await sql`LOCK TABLE routing_node_edges, routing_destinations IN ACCESS EXCLUSIVE MODE`;
  await sql`
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM routing_node_edges) OR EXISTS (SELECT 1 FROM routing_destinations) THEN
        RAISE EXCEPTION 'Cannot roll back populated node routing data. Export the data first.';
      END IF;
    END $$
  `;
  await sql`DROP TABLE routing_destinations`;
  await sql`DROP TABLE routing_node_edges`;
}
