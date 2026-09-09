import { readFileSync } from "node:fs";
import { beforeEach, expect, it, vi } from "vitest";
import { importQgisDataset } from "./import-qgis";

const { tx, begin } = vi.hoisted(() => {
  const tx = vi.fn();
  return { tx, begin: vi.fn(async callback => callback(tx)) };
});
vi.mock("@/lib/db", () => ({ sql: { begin } }));
const read = (name: string) => JSON.parse(readFileSync(`data/muj/${name}.geojson`, "utf8"));
const data = { nodes: read("nodes"), edges: read("edges"), destinations: read("destinations") };
const campusId = "11111111-1111-4111-8111-111111111111";

beforeEach(() => { vi.clearAllMocks(); tx.mockReset(); tx.mockResolvedValue([{ id: campusId }]); });

it("imports every feature in one transaction and returns the known warnings", async () => {
  expect(await importQgisDataset(campusId, data)).toMatchObject({ nodes: 118, edges: 153, destinations: 7 });
  expect(begin).toHaveBeenCalledTimes(1);
  expect(tx).toHaveBeenCalledTimes(4);
  const edgeFeatures = JSON.parse(tx.mock.calls[2][2]);
  expect(edgeFeatures).toEqual(data.edges.features);
});

it("rejects invalid IDs and missing references before starting a transaction", async () => {
  await expect(importQgisDataset("bad", data)).rejects.toThrow();
  const invalid = structuredClone(data);
  invalid.destinations.features[0].properties.routing_node_id = "OUT_MISSING_0_999";
  await expect(importQgisDataset(campusId, invalid)).rejects.toThrow("references a missing node");
  expect(begin).not.toHaveBeenCalled();
});

it("rejects unknown campuses without inserting records", async () => {
  tx.mockResolvedValueOnce([]);
  await expect(importQgisDataset(campusId, data)).rejects.toThrow("does not exist");
  expect(tx).toHaveBeenCalledTimes(1);
});

it("propagates write failures to the transaction for rollback", async () => {
  tx.mockResolvedValueOnce([{ id: campusId }]).mockResolvedValueOnce([]).mockRejectedValueOnce(new Error("write failed"));
  await expect(importQgisDataset(campusId, data)).rejects.toThrow("write failed");
  expect(tx).toHaveBeenCalledTimes(3);
});
