import assert from "node:assert/strict";
import { sql } from "../lib/db";
import { findShortestPath } from "../lib/routing/graph";
import { createObstructionReport, fetchCampusReports } from "../lib/spatial/reports";

assert.equal(process.env.OBSTRUCTION_TEST, "1", "Set OBSTRUCTION_TEST=1 for a disposable database");
const [campus, building, from, to, edge] = Array.from({ length: 5 }, () => crypto.randomUUID());
try {
  await sql.begin(async tx => {
    await tx`INSERT INTO campuses (id, name, bounds) VALUES (${campus}, 'Obstruction test', ST_GeomFromText('POLYGON((0 0,0 1,1 1,1 0,0 0))',4326))`;
    await tx`INSERT INTO buildings (id, campus_id, name, outline) VALUES (${building}, ${campus}, 'Test', ST_GeomFromText('POLYGON((0 0,0 1,1 1,1 0,0 0))',4326))`;
    await tx`
      INSERT INTO rooms (id, building_id, name, floor, geom)
      SELECT id, ${building}, 'Test room', '0', ST_GeomFromText('POLYGON((0 0,0 1,1 1,1 0,0 0))',4326)
      FROM unnest(${[from, to]}::uuid[]) id
    `;
    await tx`
      INSERT INTO routing_edges (id, source_node_id, target_node_id, distance_meters, floor_id, geom)
      VALUES (${edge}, ${from}, ${to}, 10, '0', ST_GeomFromText('LINESTRING(0 0,1 1)',4326))
    `;
  });
  assert.ok(await findShortestPath(from, to, false));
  const report = await createObstructionReport({ edgeId: edge, description: "Test closure" });
  assert.equal(await findShortestPath(from, to, false), null);
  const open = await fetchCampusReports(campus);
  assert.equal(open.total, 1);
  assert.equal(open.reports[0].id, report.id);
  assert.equal(open.reports[0].room_id, null);
  assert.equal((await fetchCampusReports(crypto.randomUUID())).total, 0);
  await sql`UPDATE obstruction_reports SET status = 'resolved', resolved_at = now() WHERE id = ${report.id}`;
  assert.ok(await findShortestPath(from, to, false));
  assert.equal((await fetchCampusReports(campus)).total, 0);
  assert.equal((await fetchCampusReports(campus, "resolved")).total, 1);
  console.log("Obstruction checks passed: immediate closure/reopening and campus-scoped edge-only reports.");
} finally {
  await sql`DELETE FROM obstruction_reports WHERE edge_id = ${edge}`;
  await sql`DELETE FROM campuses WHERE id = ${campus}`;
  await sql.end();
}
