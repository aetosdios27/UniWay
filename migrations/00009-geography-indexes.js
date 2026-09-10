// Meter-radius queries cast geometry to geography; geometry GiST indexes cannot
// support those ST_DWithin predicates. Keep them for geometry/KNN callers.
export async function up(sql) {
  await sql`CREATE INDEX IF NOT EXISTS routing_nodes_geography_idx ON routing_nodes USING GIST ((geom::geography))`;
  await sql`CREATE INDEX IF NOT EXISTS rooms_centroid_geography_idx ON rooms USING GIST ((centroid::geography))`;
}

export async function down(sql) {
  await sql`DROP INDEX IF EXISTS rooms_centroid_geography_idx`;
  await sql`DROP INDEX IF EXISTS routing_nodes_geography_idx`;
}
