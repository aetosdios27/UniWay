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
  expect(await importQgisDataset(campusId, data)).toMatchObject({ nodes: 118, edges: 153, destinations: 7, pois: 0 });
  expect(begin).toHaveBeenCalledTimes(1);
  expect(tx).toHaveBeenCalledTimes(4);
  const edgeFeatures = JSON.parse(tx.mock.calls[2][2]);
  expect(edgeFeatures).toEqual(data.edges.features);
});

it("imports POIs into campus_pois when present in the dataset", async () => {
  const withPois = structuredClone(data);
  (withPois as Record<string, unknown>).pois = {
    type: "FeatureCollection",
    features: [
      {
        type: "Feature",
        properties: {
          id: "POI_01",
          name: "Main Cafeteria",
          category: "food",
          icon_key: "food",
          tags: ["canteen"],
          routing_node_id: "OUT_ADM_0_092",
        },
        geometry: { type: "Point", coordinates: [75.565927, 26.8416371] },
      },
    ],
  };

  const result = await importQgisDataset(campusId, withPois);
  expect(result).toMatchObject({
    nodes: 118,
    edges: 153,
    destinations: 7,
    pois: 1,
  });
  expect(tx).toHaveBeenCalledTimes(5);
  const poiFeatures = JSON.parse(tx.mock.calls[4][2]);
  expect(poiFeatures).toHaveLength(1);
  expect(poiFeatures[0].properties.id).toBe("POI_01");
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
