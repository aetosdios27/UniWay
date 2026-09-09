# Track B: Routing Engine

> **Agent Instruction:** You are acting as the AI pair programmer for Track B. Read this document to understand your specific domain, architectural constraints, and deliverables. Do not touch files related to Track A (Database/SQL).

## Domain Objective
Your goal is to build the in-memory graph engine that powers UniWay's routing. You are responsible for loading edges into `graphology`, running Dijkstra shortest-path calculations, and assembling GeoJSON.

## Architecture Constraints
1. **Engine:** Use `graphology` and `graphology-shortest-path`.
2. **Database Access:** ZERO database access. You will build your logic around the `RoutingEdge` interface and use mocked arrays of edges for testing until Track A finishes their SQL functions.
3. **Freshness:** Reload current edges on each request so obstruction changes are visible across application instances. Do not restore process-local route caching without shared invalidation/versioning.

## Deliverables

### 1. Graph Builder (`lib/routing/graph.ts`)
- Create a function that accepts an array of `RoutingEdge` objects and builds an undirected graph using `graphology`.
- The edge weights must be the `distance_meters`.

### 2. Dijkstra Execution (`lib/routing/graph.ts`)
- Implement the shortest-path logic.
- Crucially, it must accept an `accessibilityRequired: boolean` flag. If `true`, the pathfinding must drop/ignore any edge where `is_accessible` is `false` (i.e., routing around stairs).

### 3. Route Freshness
- The former 24-hour process-local cache was removed because it could return blocked routes.
- Add shared versioned caching only if measured routing latency warrants it.

### 4. GeoJSON Assembly (`lib/routing/route-assembly.ts`)
- The output of the Dijkstra algorithm is a sequence of node IDs.
- Write a utility to convert this sequence back into a standard GeoJSON `LineString` feature that MapLibre GL JS can directly ingest.

## The Data Contract
You will receive data that looks exactly like this from Track A. Use it to build your mock data arrays for your Vitest tests.

```typescript
export interface RoutingEdge {
  id: string;
  source_node_id: string; 
  target_node_id: string; 
  distance_meters: number; 
  is_accessible: boolean; 
  floor_id: string;
}
```

## Workflow Rules
- Write Vitest tests for your routing logic using hardcoded `RoutingEdge` arrays. Minimum 80% coverage is required by CI.
- Adhere to conventional commits for your PRs (`feat:`, `fix:`, `chore:`).
