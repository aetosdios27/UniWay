# QGIS routing node import

Migration 00007 adds routing_nodes alongside existing room-based routing.
It can run on a populated database without changing existing edges or reports.
Ley supplies the transaction; rollback refuses to delete populated nodes.

RoutingNodesFileSchema validates the QGIS FeatureCollection. The importer must
supply campus_id, convert geometry to PostGIS geom, and preserve node_id text
including zero padding. The database enforces uniqueness within each campus.

RoutingEdgeSchema remains the live UUID/room-based edge contract. The supplied
export is validated by QgisDatasetSchema; NodeEdgeSchema derives the new query
contract from it. Migration 00008 stores readable edge IDs in routing_node_edges
and destination IDs in routing_destinations. Only campus IDs remain UUIDs in
this new graph; QGIS node IDs are stored directly, with no generated node UUID.

## Node API (separate from legacy room routing)

- GET /api/campus/{campusId}/destinations returns `{ data: [...] }`, with each
  destination's id, name, type, routing_node_id and Point geom.
- GET /api/campus/{campusId}/node-route accepts fromLng, fromLat, toNodeId,
  optional floor (default 0) and accessible=true|false (default false).
  Returns `{ data: <GeoJSON LineString Feature> }`, with distance_meters.

Snapping selects the nearest node within 50 metres on the requested floor, in
the specified campus. Accessible routing excludes inaccessible nodes and edges.
Unknown or disconnected destinations return 404. The old toRoomId API is unchanged.

Paths follow stored edge geometry in either direction and choose the cheapest
usable parallel edge. E00143 remains a Point in storage; a route containing only
that edge repeats its coordinate to form a valid LineString and retains its
declared distance. No source data is repaired or removed.

The small graph is loaded per request and responses use no-store, avoiding stale
routes across imports or application instances. Add versioned caching only if
latency measurements justify it. Node-edge obstruction reporting and the mobile
switch are separate follow-ups; existing reports still reference legacy edges.
