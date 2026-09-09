import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { sql } from "../lib/db";
import { getNearestRoutingNode } from "../lib/spatial/nodes";
import { findRoomsWithinRadius } from "../lib/spatial/proximity";
import { findNodeRoute } from "../lib/routing/nodes";
import { importQgisDataset } from "../lib/spatial/import-qgis";
import * as migration from "../migrations/00009-geography-indexes.js";

// This destructive fixture/DDL workload is deliberately restricted to a disposable local database.
const target = new URL(process.env.DATABASE_URL || "postgres://invalid/invalid");
assert(["localhost", "127.0.0.1", "[::1]"].includes(target.hostname) && target.pathname === "/uniway_stress",
  "Stress testing requires a local database named uniway_stress; never use production credentials.");
const scaleCampus = "10000000-0000-4000-8000-000000000001";
const mapCampus = "10000000-0000-4000-8000-000000000002";
const building = "10000000-0000-4000-8000-000000000003";
const records: unknown[] = [];

async function prepare() {
  assert.equal(Number((await sql`SELECT count(*) FROM campuses`)[0].count), 0, "Prepare requires an empty database");
  await sql`INSERT INTO campuses (id,name,bounds) VALUES
    (${scaleCampus}, 'Stress scale', ST_MakeEnvelope(70,20,80,30,4326)),
    (${mapCampus}, 'Stress QGIS', ST_MakeEnvelope(70,20,80,30,4326))`;
  await sql`INSERT INTO buildings (id,campus_id,name,outline) VALUES
    (${building},${scaleCampus},'Stress building',ST_MakeEnvelope(70,20,80,30,4326))`;
  await sql`INSERT INTO routing_nodes (campus_id,node_id,nid,loc,node_type,floor_id,is_accessible,geom)
    SELECT ${scaleCampus}, 'OUT_STRESS_0_' || lpad(i::text,6,'0'), i, 'Stress', 'junction', '0', true,
      ST_SetSRID(ST_MakePoint(75 + ((i-1)%400)*0.001,26 + ((i-1)/400)*0.001),4326)
    FROM generate_series(1,100000) i`;
  await sql`INSERT INTO rooms (building_id,floor,name,geom)
    SELECT ${building},'0','Stress ' || i, ST_MakeEnvelope(x-0.00001,y-0.00001,x+0.00001,y+0.00001,4326)
    FROM (SELECT i,75+((i-1)%200)*0.001 x,26+((i-1)/200)*0.001 y FROM generate_series(1,20000) i) points`;
  const load = async (name: string) => JSON.parse(await readFile(`data/muj/${name}.geojson`, "utf8"));
  console.log(await importQgisDataset(mapCampus, {nodes: await load("nodes"), edges: await load("edges"), destinations: await load("destinations")}));
  await sql`ANALYZE`;
  console.log(JSON.stringify({prepared: true, scaleNodes: 100000, scaleRooms: 20000, scaleCampus, mapCampus}));
}

async function workload(name: string, concurrency: number, count: number, run: (i: number) => Promise<unknown>, durationMs = 0) {
  const latency: number[] = [];
  const errors: string[] = [];
  let next = 0;
  const start = performance.now();
  await Promise.all(Array.from({length: concurrency}, async () => {
    while (durationMs ? performance.now() - start < durationMs : next < count) {
      const i = next++;
      const began = performance.now();
      try { await run(i); } catch (error) { errors.push(String(error)); }
      latency.push(performance.now() - began);
    }
  }));
  const elapsed = performance.now() - start;
  latency.sort((a,b) => a-b);
  const percentile = (p: number) => Math.round(latency[Math.ceil(p*latency.length)-1]*100)/100;
  const result = {name, concurrency, requests: latency.length, durationMs: Math.round(elapsed), errors: errors.length, samples: errors.slice(0,3), rps: Math.round(latency.length/elapsed*1000), p50: percentile(.5), p95: percentile(.95), p99: percentile(.99)};
  records.push(result);
  console.log(JSON.stringify(result));
  assert.equal(errors.length, 0, `${name} failed`);
}

async function plans(label: string) {
  const node = await sql`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT campus_id,node_id,nid,loc,node_type,floor_id,is_accessible,ST_AsGeoJSON(geom,15)::json AS geom
    FROM routing_nodes WHERE campus_id=${scaleCampus} AND floor_id='0' AND (NOT false OR is_accessible)
    AND ST_DWithin(geom::geography,ST_SetSRID(ST_MakePoint(75,26),4326)::geography,50)
    ORDER BY ST_Distance(geom::geography,ST_SetSRID(ST_MakePoint(75,26),4326)::geography),node_id LIMIT 1`;
  const room = await sql`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT r.id,r.building_id,r.floor,r.name,ST_AsGeoJSON(r.geom)::json AS geom,ST_AsGeoJSON(r.centroid)::json AS centroid
    FROM rooms r JOIN buildings b ON r.building_id=b.id WHERE b.campus_id=${scaleCampus}
    AND ST_DWithin(r.centroid::geography,ST_SetSRID(ST_MakePoint(75,26),4326)::geography,50)
    ORDER BY r.centroid <-> ST_SetSRID(ST_MakePoint(75,26),4326),r.id`;
  const result = {label,node: node[0]["QUERY PLAN"],room: room[0]["QUERY PLAN"]};
  records.push(result);
  console.log(JSON.stringify(result));
}

async function compare() {
  const nearest = async () => assert.equal((await getNearestRoutingNode(scaleCampus,75,26,"0",false))?.node_id,"OUT_STRESS_0_000001");
  const rooms = async () => assert.equal((await findRoomsWithinRadius(75,26,scaleCampus,50)).length,1);
  try {
    await sql.begin(tx => migration.down(tx));
    await sql`ANALYZE`;
    await plans("before");
    for (const c of [1,8,32,64]) await workload("nearest-before",c,128,nearest);
    await workload("rooms-before",16,128,rooms);
  } finally {
    // Restore schema even if a workload assertion fails.
    await sql.begin(async tx => { await migration.down(tx); await migration.up(tx); });
    await sql`ANALYZE`;
  }
  await plans("after");
  for (const c of [1,8,32,64]) await workload("nearest-after",c,128,nearest);
  await workload("rooms-after",16,128,rooms);
  assert.equal(await getNearestRoutingNode(scaleCampus,75,26,"missing",false),null);
  assert.equal(await getNearestRoutingNode(mapCampus,75,26,"0",false),null);
  assert.equal(await getNearestRoutingNode(scaleCampus,70,20,"0",true),null);
  const [edge] = await sql`SELECT source_node_id,target_node_id FROM routing_node_edges WHERE campus_id=${mapCampus} LIMIT 1`;
  for (const c of [1,8,32,64]) await workload("qgis-route",c,256,async () => {
    const route = await findNodeRoute(mapCampus,edge.source_node_id,edge.target_node_id,false);
    assert(route && route.properties.distance_meters > 0);
  });
  await workload("mixed-soak",32,3000,async i => {
    if(i%3===0) return nearest();
    if(i%3===1) return rooms();
    assert(await findNodeRoute(mapCampus,edge.source_node_id,edge.target_node_id,false));
  });
  console.log(JSON.stringify({correctness:"passed",memory:process.memoryUsage()}));
}

async function http() {
  const origin = new URL(process.env.STRESS_ORIGIN || "http://127.0.0.1:3300");
  assert(["localhost", "127.0.0.1", "[::1]"].includes(origin.hostname), "HTTP stress requires a local origin");
  const [edge] = await sql`
    SELECT e.target_node_id,ST_X(n.geom) lng,ST_Y(n.geom) lat,n.floor_id
    FROM routing_node_edges e JOIN routing_nodes n
      ON n.campus_id=e.campus_id AND n.node_id=e.source_node_id
    WHERE e.campus_id=${mapCampus} LIMIT 1`;
  const routePath = `/api/campus/${mapCampus}/node-route?${new URLSearchParams({
    fromLng: String(edge.lng), fromLat: String(edge.lat), toNodeId: edge.target_node_id, floor: edge.floor_id,
  })}`;
  let client = 0;
  const request = async (path: string, init?: RequestInit) => {
    const response = await fetch(new URL(path,origin), {
      ...init, signal: AbortSignal.timeout(15000),
      // Simulated independent clients at the local reverse-proxy boundary.
      headers: {"x-forwarded-for": `198.18.${Math.floor(++client/250)%250}.${client%250}`, ...init?.headers},
    });
    const body = await response.json();
    assert(response.ok, `${response.status}: ${JSON.stringify(body)}`);
    return {response,body};
  };
  await request(routePath);
  for (const c of [1,8,32,64,128]) await workload("http-node-route",c,256,async () => {
    const {response,body} = await request(routePath);
    assert.equal(response.headers.get("cache-control"),"no-store");
    assert(body.data.properties.distance_meters > 0);
  });
  const [room] = await sql`SELECT id FROM rooms WHERE building_id=${building} LIMIT 1`;
  const before = Number((await sql`SELECT count(*) FROM obstruction_reports WHERE room_id=${room.id}`)[0].count);
  await workload("http-report-writes",32,256,async i => {
    const {response,body} = await request("/api/report", {
      method:"POST",headers:{"content-type":"application/json"},
      body:JSON.stringify({roomId:room.id,description:`Stress report ${i}`}),
    });
    assert.equal(response.status,201);
    assert.equal(body.data.room_id,room.id);
  });
  assert.equal(Number((await sql`SELECT count(*) FROM obstruction_reports WHERE room_id=${room.id}`)[0].count),before+256);
  await workload("http-mixed-soak",32,3000,async i => {
    if (i%3===0) return request(routePath);
    if (i%3===1) {
      const {body} = await request(`/api/campus/${scaleCampus}/reports`);
      assert(body.pagination.total >= 256);
      return;
    }
    const {body} = await request(`/api/campus/${mapCampus}/destinations`);
    assert.equal(body.data.length,7);
  }, 60_000);
  const statuses: Record<number,number> = {};
  for(let i=0;i<65;i++) {
    const response = await fetch(new URL(routePath,origin), {headers:{"x-forwarded-for":"192.0.2.254"},signal:AbortSignal.timeout(15000)});
    await response.arrayBuffer();
    statuses[response.status]=(statuses[response.status]||0)+1;
    if(response.status===429) assert(Number(response.headers.get("retry-after")) > 0);
  }
  assert.equal(statuses[200],60);
  assert.equal(statuses[429],5);
  console.log(JSON.stringify({rateLimit:statuses, writeIntegrity:"passed"}));
}

try {
  const command = process.argv[2];
  if (command === "prepare") await prepare();
  else if (command === "compare") await compare();
  else if (command === "http") await http();
  else throw new Error("Usage: DATABASE_URL=postgres://...@127.0.0.1:55432/uniway_stress bun scripts/stress-backend.ts prepare|compare|http");
} finally {
  if (process.env.STRESS_RESULTS) await writeFile(process.env.STRESS_RESULTS, JSON.stringify(records,null,2));
  await sql.end();
}
