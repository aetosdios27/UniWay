import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { checkNodeNames, checkSequentialNids, PoiFeatureCollectionSchema, PoiFeatureSchema, QgisDatasetSchema, validateQgisDataset, type QgisDataset } from "./qgis";

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

describe("POI and destination schemas and dataset validation", () => {
  it("accepts destinations with valid category, icon_key, and default tags", () => {
    const data = validSample();
    expect(data.destinations.features[0].properties.category).toBe("dome");
    expect(data.destinations.features[0].properties.icon_key).toBe("dome");
    expect(data.destinations.features[0].properties.tags).toEqual([]);
  });

  it("accepts an optional pois FeatureCollection that is empty", () => {
    const data = validSample();
    data.pois = { type: "FeatureCollection", features: [] };
    const validated = validateQgisDataset(data);
    expect(validated.errors).toEqual([]);
    expect(validated.stats.totalPois).toBe(0);
  });

  it("accepts valid POIs and validates icon_key", () => {
    const data = validSample();
    data.pois = PoiFeatureCollectionSchema.parse({
      type: "FeatureCollection",
      features: [
        {
          type: "Feature",
          properties: {
            id: "POI_01",
            name: "Main Cafeteria",
            category: "food",
            icon_key: "food",
            tags: ["canteen", "snacks"],
            routing_node_id: "OUT_ADM_0_092",
          },
          geometry: { type: "Point", coordinates: [75.565, 26.841] },
        },
      ],
    });
    const validated = validateQgisDataset(data);
    expect(validated.errors).toEqual([]);
    expect(validated.stats.totalPois).toBe(1);
  });

  it("rejects unknown icon_key with clear message listing allowed keys", () => {
    const invalid = {
      type: "Feature",
      properties: {
        id: "POI_BAD",
        name: "Bad POI",
        category: "food",
        icon_key: "non_existent_key",
        routing_node_id: "OUT_ADM_0_092",
      },
      geometry: { type: "Point", coordinates: [75.565, 26.841] },
    };
    const result = PoiFeatureSchema.safeParse(invalid);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toContain("Invalid icon_key");
      expect(result.error.issues[0].message).toContain("default, academic");
    }
  });

  it("rejects duplicate poi ids", () => {
    const data = validSample();
    const poi = {
      type: "Feature" as const,
      properties: {
        id: "POI_DUP",
        name: "Duplicate POI",
        category: "dome",
        routing_node_id: "OUT_ADM_0_092",
      },
      geometry: { type: "Point" as const, coordinates: [75.565, 26.841] as [number, number] },
    };
    data.pois = PoiFeatureCollectionSchema.parse({
      type: "FeatureCollection",
      features: [poi, poi],
    });
    const validated = validateQgisDataset(data);
    expect(validated.errors).toContain("Duplicate poi id: POI_DUP");
  });

  it("rejects routing_node_id referencing a missing node in POIs", () => {
    const data = validSample();
    data.pois = PoiFeatureCollectionSchema.parse({
      type: "FeatureCollection",
      features: [
        {
          type: "Feature",
          properties: {
            id: "POI_MISSING",
            name: "Missing Node POI",
            category: "food",
            routing_node_id: "OUT_MISSING_0_999",
          },
          geometry: { type: "Point", coordinates: [75.565, 26.841] },
        },
      ],
    });
    const validated = validateQgisDataset(data);
    expect(validated.errors).toContain("POI POI_MISSING references a missing node");
  });
});
