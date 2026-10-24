// Ley wraps migrations in a transaction. Do not execute up/down outside one.
export async function up(sql) {
  await sql`
    ALTER TABLE routing_destinations
      ADD COLUMN category TEXT,
      ADD COLUMN icon_key TEXT,
      ADD COLUMN tags TEXT[] NOT NULL DEFAULT '{}'
  `;

  await sql`
    CREATE TABLE campus_pois (
      campus_id UUID NOT NULL REFERENCES campuses(id) ON DELETE CASCADE,
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      icon_key TEXT,
      tags TEXT[] NOT NULL DEFAULT '{}',
      routing_node_id TEXT,
      geom GEOMETRY(Point, 4326) NOT NULL,
      PRIMARY KEY (campus_id, id),
      FOREIGN KEY (campus_id, routing_node_id) REFERENCES routing_nodes(campus_id, node_id)
    )
  `;

  await sql`CREATE INDEX campus_pois_geom_idx ON campus_pois USING GIST (geom)`;
}

export async function down(sql) {
  await sql`LOCK TABLE campus_pois, routing_destinations IN ACCESS EXCLUSIVE MODE`;
  await sql`
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM campus_pois) OR EXISTS (
        SELECT 1 FROM routing_destinations
        WHERE category IS NOT NULL OR icon_key IS NOT NULL OR tags <> '{}'
      ) THEN
        RAISE EXCEPTION 'Cannot roll back populated POI data. Export the data first.';
      END IF;
    END $$
  `;
  await sql`DROP TABLE campus_pois`;
  await sql`
    ALTER TABLE routing_destinations
      DROP COLUMN category,
      DROP COLUMN icon_key,
      DROP COLUMN tags
  `;
}
