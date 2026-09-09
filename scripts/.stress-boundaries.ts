import assert from 'node:assert/strict';
import { sql } from '../lib/db';
import { getNearestRoutingNode } from '../lib/spatial/nodes';
const url = new URL(process.env.DATABASE_URL!);
assert.equal(url.hostname,'127.0.0.1');
assert.equal(url.pathname,'/uniway_stress');
const campus = crypto.randomUUID();
try {
  await sql`INSERT INTO campuses(id,name,bounds) VALUES (${campus},'Boundary checks',ST_MakeEnvelope(74,25,76,27,4326))`;
  await sql`INSERT INTO routing_nodes(campus_id,node_id,nid,loc,node_type,floor_id,is_accessible,geom)
    SELECT ${campus},'OUT_BOUNDARY_0_' || lpad(i::text,3,'0'),i,'Boundary','junction',floor,accessible,
    ST_Project(ST_SetSRID(ST_MakePoint(75,26),4326)::geography,distance,0)::geometry
    FROM (VALUES (1,'0',false,0.0),(2,'1',true,0.0),(3,'0',true,49.9),(4,'0',true,49.9),(5,'0',true,50.1)) v(i,floor,accessible,distance)`;
  assert.equal((await getNearestRoutingNode(campus,75,26,'0',false))?.node_id,'OUT_BOUNDARY_0_001');
  assert.equal((await getNearestRoutingNode(campus,75,26,'0',true))?.node_id,'OUT_BOUNDARY_0_003');
  assert.equal((await getNearestRoutingNode(campus,75,26,'1',true))?.node_id,'OUT_BOUNDARY_0_002');
  await sql`DELETE FROM routing_nodes WHERE campus_id=${campus} AND nid IN (1,3,4)`;
  assert.equal(await getNearestRoutingNode(campus,75,26,'0',true),null);
  let cancelled = false;
  try { await sql.begin(async tx => {await tx`SET LOCAL statement_timeout = '50ms'`; await tx`SELECT pg_sleep(1)`;}); }
  catch (error) {assert.equal((error as {code:string}).code,'57014'); cancelled=true;}
  assert(cancelled,'Statement timeout must cancel slow work');
  assert.equal((await sql`SELECT 42 AS answer`)[0].answer,42);
  console.log('PASS: 49.9/50.1m boundary, exact ties, accessibility, floor isolation, statement cancellation and pool recovery');
} finally {await sql`DELETE FROM campuses WHERE id=${campus}`; await sql.end();}
