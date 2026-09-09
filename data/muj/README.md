# MUJ QGIS dataset

Source: routing_nodes.geojson exported September 5, 2026, plus routing_edges.geojson
and destinations.geojson from the supplied uniway_geojson directory.

The node file is unchanged. Edge/destination references were translated from the
older node names to the new OUT_LOC_FLOOR_NID names using unique nid values.
Every old/new node geometry matched exactly before this translation. Original
Downloads files were not modified. Edge IDs (E00001 etc.) and destination IDs
(DEST_01 etc.) remain text; edge_type is walkway in this export.

Run: bun scripts/check-campus-data.ts

Known issues are warnings, not import blockers. E00143 has Point geometry, connecting
OUT_AB2_0_109 and OUT_AB2_0_083 at identical coordinates. It claims a distance
of approximately 0.005 metres. Preserve this geometry, distance and both nodes
unchanged; source corrections are deferred to a later iteration.

Nodes OUT_AB3_0_114 and OUT_AB3_0_115 form a disconnected two-node
component. Do not invent a connecting walkway without source data.

All 118 nodes, 153 edges and 7 destinations pass validation with warnings.
Including every edge leaves components of 116 and 2 nodes. No records are
excluded. Duplicate identities and missing references remain errors.

The check does not write to the database. After applying migrations, import with:

```sh
bun scripts/import-qgis.ts <existing-campus-uuid> data/muj
```

Set DATABASE_URL explicitly to the intended database. The importer uses one
transaction and upserts by campus and readable ID. Re-running updates supplied
records without deleting omitted records. It does not create a campus, buildings,
rooms or demo data. Point geometry is stored unchanged. Existing room-based
routing remains separate and is not switched over by this import.

For a disposable database with migrations applied, run the exact round-trip check:

```sh
QGIS_IMPORT_TEST=1 bun scripts/check-qgis-import.ts
```

This creates two temporary test campuses and removes only those campuses afterward.
