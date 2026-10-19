import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { checkNodeNames, checkSequentialNids, QgisDatasetSchema, validateQgisDataset, type QgisDataset } from "./qgis";

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

  it("rejects a gapped NID sequence and states the missing values", () => {
    const data = validSample();
    // remove nid 60 and renumber another node to 300, keeping its id canonical
    data.nodes.features.splice(
      data.nodes.features.findIndex(f => f.properties.nid === 60),
      1,
    );
    const bumped = data.nodes.features[data.nodes.features.length - 1];
    bumped.properties.nid = 300;
    bumped.properties.node_id = `OUT_${bumped.properties.loc}_9_300`;
    const result = validateQgisDataset(data);
    expect(result.errors).toEqual(expect.arrayContaining([
      expect.stringContaining("Missing sequential NIDs between 1 and 300"),
      expect.stringContaining(", and 83 more"),
    ]));
    expect(result.stats.missingNids).toHaveLength(100);
  });

  it("rejects a node whose id disagrees with its composed properties", () => {
    const data = validSample();
    data.nodes.features[0].properties.node_id = "OUT_AB1_0_999";
    const errors = validateQgisDataset(data).errors;
    expect(errors).toEqual(expect.arrayContaining([
      expect.stringContaining("Node name mismatch: node has id 'OUT_AB1_0_999'"),
      expect.stringContaining("require 'OUT_SPC_0_048'"),
    ]));
  });
});

type NodeFeature = QgisDataset["nodes"]["features"][number];

function testNode(nid: number, overrides: Partial<NodeFeature["properties"]> = {}): NodeFeature {
  return {
    type: "Feature",
    properties: {
      node_id: `OUT_TEST_0_${String(nid).padStart(3, "0")}`,
      nid,
      loc: "TEST",
      node_type: "junction",
      floor_id: "0",
      is_accessible: true,
      ...overrides,
    },
    geometry: { type: "Point", coordinates: [75.564, 26.842] },
  };
}

describe("checkSequentialNids", () => {
  it("treats an empty list as a valid empty range", () => {
    expect(checkSequentialNids([])).toEqual({
      minNid: 0,
      maxNid: 0,
      count: 0,
      expectedCount: 0,
      missingCount: 0,
      missingNids: [],
      isSequential: true,
    });
  });

  it("accepts an unordered contiguous set without enumerating gaps", () => {
    expect(checkSequentialNids([3, 1, 2])).toEqual(expect.objectContaining({
      minNid: 1,
      maxNid: 3,
      count: 3,
      expectedCount: 3,
      missingCount: 0,
      missingNids: [],
      isSequential: true,
    }));
  });

  it("reports exactly the missing NIDs of a small gap", () => {
    expect(checkSequentialNids([1, 2, 5, 6])).toEqual(expect.objectContaining({
      minNid: 1,
      maxNid: 6,
      count: 4,
      expectedCount: 6,
      missingCount: 2,
      missingNids: [3, 4],
      isSequential: false,
    }));
  });

  it("deduplicates before testing continuity", () => {
    expect(checkSequentialNids([1, 1, 2])).toEqual(expect.objectContaining({ count: 2, missingCount: 0, isSequential: true }));
    expect(checkSequentialNids([1, 1, 3])).toEqual(expect.objectContaining({ count: 2, missingCount: 1, missingNids: [2] }));
  });

  it("caps the reported gaps so a huge range cannot exhaust memory", () => {
    const result = checkSequentialNids([1, 2, 2_147_483_646]);
    expect(result.isSequential).toBe(false);
    expect(result.missingCount).toBe(2_147_483_643);
    expect(result.missingNids).toHaveLength(100);
    expect(result.missingNids[0]).toBe(3);
  });
});

describe("checkNodeNames", () => {
  it("accepts ids composed from the provided nid, loc and floor_id", () => {
    expect(checkNodeNames([testNode(1), testNode(109)])).toEqual([]);
  });

  it("accepts ids above three digits and non-numeric floor ids", () => {
    expect(checkNodeNames([testNode(1234, { node_id: "OUT_TEST_L2_1234", floor_id: "L2" })])).toEqual([]);
  });

  it("rejects ids that disagree with their properties or padding", () => {
    const withWrongNid = testNode(5, { node_id: "OUT_TEST_0_006" });
    const withWrongLoc = testNode(7, { node_id: "OUT_POLICY_0_007" });
    expect(checkNodeNames([withWrongNid])[0]).toContain("id 'OUT_TEST_0_006', but properties (loc: 'TEST', floor_id: '0', nid: 5) require 'OUT_TEST_0_005'");
    expect(checkNodeNames([withWrongLoc])[0]).toContain("require 'OUT_TEST_0_007'");
  });
});
