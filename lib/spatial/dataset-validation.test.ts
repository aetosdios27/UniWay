import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, describe, expect, it } from "vitest";
import { checkDirectoryJsonIntegrity, safeReadJson, validateDatasetDirectory } from "./dataset-validation";

const tempRoots: string[] = [];
afterAll(() => {
  for (const root of tempRoots) rmSync(root, { recursive: true, force: true });
});

function fixtureRoot(): string {
  const root = mkdtempSync(join(tmpdir(), "uniway-dataset-"));
  tempRoots.push(root);
  return root;
}

function writeDataset(root: string, overrides: {
  nodes?: unknown;
  edges?: unknown;
  destinations?: unknown;
  extraFiles?: Record<string, string | Buffer>;
  subdirectory?: Record<string, string>;
} = {}): string {
  const dir = join(root, "muj");
  mkdirSync(dir, { recursive: true });
  const files: Record<string, unknown> = {
    "nodes.geojson": overrides.nodes ?? validFixture().nodes,
    "edges.geojson": overrides.edges ?? validFixture().edges,
    "destinations.geojson": overrides.destinations ?? validFixture().destinations,
    ...overrides.extraFiles,
  };
  for (const [name, content] of Object.entries(files)) {
    writeFileSync(join(dir, name), typeof content === "string" || Buffer.isBuffer(content) ? content : JSON.stringify(content));
  }
  if (overrides.subdirectory) {
    const nested = join(dir, "nested");
    mkdirSync(nested);
    for (const [name, content] of Object.entries(overrides.subdirectory)) {
      writeFileSync(join(nested, name), content);
    }
  }
  return dir;
}

function validFixture() {
  return {
    nodes: {
      type: "FeatureCollection",
      features: [
        node(1),
        node(2),
      ],
    },
    edges: {
      type: "FeatureCollection",
      features: [
        {
          type: "Feature",
          properties: {
            edge_id: "E00001",
            source_node_id: "OUT_TEST_0_001",
            target_node_id: "OUT_TEST_0_002",
            distance_meters: 130.5,
            is_accessible: true,
            floor_id: "0",
            edge_type: "walkway",
          },
          geometry: { type: "LineString", coordinates: [[75.564, 26.842], [75.565, 26.843]] },
        },
      ],
    },
    destinations: {
      type: "FeatureCollection",
      features: [
        {
          type: "Feature",
          properties: { id: "DEST_01", name: "Test Hall", type: "destination", routing_node_id: "OUT_TEST_0_002" },
          geometry: { type: "Point", coordinates: [75.565, 26.843] },
        },
      ],
    },
  };
}

function node(nid: number) {
  return {
    type: "Feature",
    properties: {
      node_id: `OUT_TEST_0_${String(nid).padStart(3, "0")}`,
      nid,
      loc: "TEST",
      node_type: "entrance",
      floor_id: "0",
      is_accessible: true,
    },
    geometry: { type: "Point", coordinates: nid === 1 ? [75.564, 26.842] : [75.565, 26.843] },
  };
}

describe("safeReadJson", () => {
  it("returns parsed data for valid JSON", () => {
    const file = join(fixtureRoot(), "ok.json");
    writeFileSync(file, '{"type":"FeatureCollection"}');
    expect(safeReadJson(file).data).toEqual({ type: "FeatureCollection" });
  });

  it("describes the parse failure for corrupted files", () => {
    const file = join(fixtureRoot(), "bad.json");
    writeFileSync(file, '{"features": [trailing');
    const result = safeReadJson(file);
    expect(result.data).toBeUndefined();
    expect(result.error).toContain(`Corrupted JSON in '${file}'`);
  });
});

describe("checkDirectoryJsonIntegrity", () => {
  it("flags a missing directory", () => {
    const missing = join(fixtureRoot(), "nowhere");
    expect(checkDirectoryJsonIntegrity(missing)).toEqual([
      expect.objectContaining({ file: missing, corrupted: true, error: expect.stringContaining("does not exist") }),
    ]);
  });

  it("scans recursively, skips non-JSON files and keeps healthy files unflagged", () => {
    const dir = writeDataset(fixtureRoot(), {
      extraFiles: { "notes.md": "not json", "schema.json": "{ invalid" },
      subdirectory: { "extra.geojson": '{"type":"FeatureCollection"}' },
    });
    const results = checkDirectoryJsonIntegrity(dir);
    expect(results.map(r => r.file.slice(dir.length + 1))).toEqual(
      expect.arrayContaining(["nodes.geojson", "edges.geojson", "destinations.geojson", "schema.json", join("nested", "extra.geojson")])
    );
    expect(results).not.toContain(expect.objectContaining({ file: expect.stringContaining("notes.md") }));
    const corrupted = results.filter(r => r.corrupted);
    expect(corrupted).toHaveLength(1);
    expect(corrupted[0].file).toContain("schema.json");
    for (const healthy of results.filter(r => !r.corrupted)) expect(healthy.error).toBeUndefined();
  });

  it("skips hidden directories, so corrupted JSON inside them is not reported", () => {
    const dir = writeDataset(fixtureRoot());
    mkdirSync(join(dir, ".cache"));
    writeFileSync(join(dir, ".cache", "stale.json"), "{ broken");
    const results = checkDirectoryJsonIntegrity(dir);
    expect(results.some(r => r.file.includes(".cache"))).toBe(false);
    expect(results.filter(r => r.corrupted)).toEqual([]);
    expect(validateDatasetDirectory(dir).corruptedFiles).toEqual([]);
  });
});

describe("validateDatasetDirectory", () => {
  it("accepts a well-formed dataset with sequential NIDs and canonical names", () => {
    const report = validateDatasetDirectory(writeDataset(fixtureRoot()));
    expect(report.valid).toBe(true);
    expect(report.errors).toEqual([]);
    expect(report.warnings).toEqual([]);
    expect(report.corruptedFiles).toEqual([]);
    expect(report.stats).toMatchObject({
      totalNodes: 2,
      minNid: 1,
      maxNid: 2,
      missingNids: [],
      totalEdges: 1,
      totalDestinations: 1,
      componentsCount: 1,
    });
  });

  it("fails fast when a required file is missing", () => {
    const dir = writeDataset(fixtureRoot());
    rmSync(join(dir, "edges.geojson"));
    const report = validateDatasetDirectory(dir);
    expect(report.valid).toBe(false);
    expect(report.errors).toContain(`Required dataset file missing: ${join(dir, "edges.geojson")}`);
    expect(report.stats.totalNodes).toBe(0);
  });

  it("reports corrupted files before any schema work", () => {
    const dir = writeDataset(fixtureRoot(), { extraFiles: { "nodes.geojson": "{ broken" } });
    const report = validateDatasetDirectory(dir);
    expect(report.valid).toBe(false);
    expect(report.corruptedFiles).toHaveLength(1);
    expect(report.errors[0]).toContain("Corrupted JSON");
  });

  it("surfaces schema violations from the zod boundary", () => {
    const fixture = validFixture();
    fixture.edges.features[0].properties.distance_meters = 0;
    const dir = writeDataset(fixtureRoot(), { edges: fixture.edges });
    const report = validateDatasetDirectory(dir);
    expect(report.valid).toBe(false);
    expect(report.errors[0]).toContain("Schema error at edges.features");
    expect(report.stats.totalNodes).toBe(0);
  });

  it("rejects gapped NID sequences through validateQgisDataset", () => {
    const fixture = validFixture();
    fixture.nodes.features[1].properties.nid = 4;
    fixture.nodes.features[1].properties.node_id = "OUT_TEST_0_004";
    const dir = writeDataset(fixtureRoot(), { nodes: fixture.nodes });
    const report = validateDatasetDirectory(dir);
    expect(report.valid).toBe(false);
    expect(report.errors).toContain("Missing sequential NIDs between 1 and 4: 2, 3");
    expect(report.stats.missingNids).toEqual([2, 3]);
  });

  it("validates the shipped data/muj dataset as a regression", () => {
    const report = validateDatasetDirectory("data/muj");
    expect(report.valid).toBe(true);
    expect(report.errors).toEqual([]);
    expect(report.corruptedFiles).toEqual([]);
    expect(report.stats).toMatchObject({
      totalNodes: 118,
      minNid: 1,
      maxNid: 118,
      missingNids: [],
      totalEdges: 153,
      totalDestinations: 7,
    });
  });
  it("validates optional pois.geojson when present and reports totalPois", () => {
    const dir = writeDataset(fixtureRoot(), {
      extraFiles: {
        "pois.geojson": JSON.stringify({
          type: "FeatureCollection",
          features: [
            {
              type: "Feature",
              properties: {
                id: "POI_01",
                name: "Test POI",
                category: "academic",
                icon_key: "academic",
                tags: ["lab"],
                routing_node_id: "OUT_TEST_0_001",
              },
              geometry: { type: "Point", coordinates: [75.564, 26.842] },
            },
          ],
        }),
      },
    });
    const report = validateDatasetDirectory(dir);
    expect(report.valid).toBe(true);
    expect(report.stats.totalPois).toBe(1);
  });

  it("accepts empty features array in pois.geojson", () => {
    const dir = writeDataset(fixtureRoot(), {
      extraFiles: {
        "pois.geojson": JSON.stringify({ type: "FeatureCollection", features: [] }),
      },
    });
    const report = validateDatasetDirectory(dir);
    expect(report.valid).toBe(true);
    expect(report.stats.totalPois).toBe(0);
  });

  it("reports a 0-byte pois.geojson as a corrupted JSON file", () => {
    const dir = writeDataset(fixtureRoot(), {
      extraFiles: { "pois.geojson": "" },
    });
    const report = validateDatasetDirectory(dir);
    expect(report.valid).toBe(false);
    expect(report.corruptedFiles).toHaveLength(1);
    expect(report.corruptedFiles[0].file).toContain("pois.geojson");
    expect(report.errors[0]).toContain("Corrupted JSON");
  });
});
