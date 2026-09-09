import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { QgisDatasetSchema, validateQgisDataset } from "./qgis";

const read = (name: string) => JSON.parse(readFileSync(`data/muj/${name}.geojson`, "utf8"));
const raw = { nodes: read("nodes"), edges: read("edges"), destinations: read("destinations") };

function validSample() {
  return QgisDatasetSchema.parse(raw);
}

describe("campus dataset validation", () => {
  it("preserves every supplied record, including the collapsed Point edge", () => {
    const data = validSample();
    expect(data.nodes.features).toHaveLength(118);
    expect(data.edges.features).toHaveLength(153);
    expect(data.destinations.features).toHaveLength(7);
    expect(data.edges.features.find(f => f.properties.edge_id === "E00143")).toEqual(raw.edges.features[140]);
  });

  it("checks remaining paths and reports duplicate locations and disconnected nodes", () => {
    const result = validateQgisDataset(validSample());
    expect(result.errors).toEqual([]);
    expect(result.warnings).toHaveLength(3);
    expect(result.warnings).toContain("Edge E00143 has Point geometry; retained unchanged");
    expect(result.components.map(c => c.length).sort((a, b) => b - a)).toEqual([116, 2]);
  });

  it("rejects duplicate identities and dangling edge/destination references", () => {
    const data = validSample();
    data.nodes.features.push(data.nodes.features[0]);
    data.edges.features[0].properties.source_node_id = "OUT_MISSING_0_999";
    data.destinations.features[0].properties.routing_node_id = "OUT_MISSING_0_999";
    const result = validateQgisDataset(data);
    expect(result.errors).toEqual(expect.arrayContaining([
      expect.stringContaining("Duplicate node_id"),
      expect.stringContaining("Duplicate nid"),
      expect.stringContaining("references a missing node"),
      expect.stringContaining("Destination DEST_01"),
    ]));
  });

  it("rejects a path drawn away from its declared endpoints", () => {
    const data = validSample();
    data.edges.features[0].geometry = { type: "LineString", coordinates: [[0, 0], [0, 0]] };
    expect(validateQgisDataset(data).errors).toContain("Edge E00001 geometry does not run from source to target");
  });
});
