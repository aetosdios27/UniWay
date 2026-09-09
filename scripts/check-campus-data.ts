import { readFileSync } from "node:fs";
import { join } from "node:path";
import { QgisDatasetSchema, validateQgisDataset } from "../lib/spatial/qgis";

const directory = process.argv[2] ?? "data/muj";
const read = (name: string) => JSON.parse(readFileSync(join(directory, `${name}.geojson`), "utf8"));
const data = QgisDatasetSchema.parse({ nodes: read("nodes"), edges: read("edges"), destinations: read("destinations") });
const result = validateQgisDataset(data);
console.log(JSON.stringify({ nodes: data.nodes.features.length, edges: data.edges.features.length, destinations: data.destinations.features.length, ...result }, null, 2));
process.exitCode = result.errors.length ? 1 : 0;
