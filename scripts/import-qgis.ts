import { readFileSync } from "node:fs";
import { join } from "node:path";
import { sql } from "../lib/db";
import { importQgisDataset } from "../lib/spatial/import-qgis";

async function main() {
  const [campusId, directory = "data/muj"] = process.argv.slice(2);
  if (!campusId) throw new Error("Usage: bun scripts/import-qgis.ts <existing-campus-uuid> [directory]");
  const read = (name: string) => JSON.parse(readFileSync(join(directory, `${name}.geojson`), "utf8"));
  const result = await importQgisDataset(campusId, {
    nodes: read("nodes"), edges: read("edges"), destinations: read("destinations"),
  });
  console.log(JSON.stringify(result, null, 2));
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => sql.end());
