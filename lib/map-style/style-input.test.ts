import { describe, expect, it } from "vitest";
import { darkenStyle } from "./dark-style";
import { parseStyleJson, resolveStyleOutput, resolveStyleSource } from "./style-input";

const style = {
  glyphs: "https://example.com/{fontstack}/{range}.pbf",
  version: 8,
  sources: { liberty: { type: "vector", url: "https://example.com/tiles", attribution: "Map data" } },
  layers: [{ id: "background", type: "background", paint: { "background-color": "#ffffff" }, layout: {} }],
  sprite: "https://example.com/sprite",
  metadata: { custom: [true, null, 42] },
  name: "Liberty",
  extension: { nested: ["value"] },
};

describe("source style validation", () => {
  it("preserves all JSON fields and key order while rebuilding validated data", () => {
    const parsed = parseStyleJson(JSON.stringify(style));
    expect(JSON.stringify(parsed)).toBe(JSON.stringify(style));
    expect(parsed).not.toBe(style);
    expect(darkenStyle(parsed)).toEqual(darkenStyle(style));
  });

  it.each([
    null, [], {}, { ...style, version: 7 }, { ...style, sources: [] },
    { ...style, sources: { invalid: { type: "unknown" } } },
    { ...style, sources: { invalid: { type: "vector", tiles: [1] } } },
    { ...style, layers: {} }, { ...style, layers: [null] },
    { ...style, layers: [{ type: "fill" }] },
    { ...style, layers: [{ id: "bad", type: "invalid" }] },
    { ...style, layers: [{ id: "bad", type: "fill", paint: [] }] },
    { ...style, layers: [{ id: "bad", type: "fill", layout: "invalid" }] },
    { ...style, glyphs: 42 }, { ...style, sprite: [] },
    { ...style, name: {} }, { ...style, metadata: [] },
  ])("rejects invalid style %j", (input) => {
    expect(() => parseStyleJson(JSON.stringify(input))).toThrow();
  });

  it("rejects malformed JSON", () => {
    expect(() => parseStyleJson("{" )).toThrow();
  });
});

describe("output containment", () => {
  it.each(["../outside.json", "nested/../../outside.json", "/tmp/outside.json"])("rejects escape %s", (output) => {
    expect(() => resolveStyleOutput("/repo", output)).toThrow(/inside/);
  });
  it.each(["asset.txt", "asset.JSON", "asset.json/child", "."])("rejects non-JSON output %s", (output) => {
    expect(() => resolveStyleOutput("/repo", output)).toThrow(/.json/);
  });
  it("resolves the default and an absolute contained path", () => {
    expect(resolveStyleOutput("/repo", "mobile/assets/map/uniway_dark_style.json"))
      .toBe("/repo/mobile/assets/map/uniway_dark_style.json");
    expect(resolveStyleOutput("/repo", "/repo/asset.json")).toBe("/repo/asset.json");
  });
});

describe("source locations", () => {
  it("accepts OpenFreeMap HTTPS and explicit local paths", () => {
    expect(resolveStyleSource("https://tiles.openfreemap.org/styles/liberty"))
      .toEqual({ kind: "url", value: "https://tiles.openfreemap.org/styles/liberty" });
    for (const value of ["./style.json", "/tmp/style.json", "style.json"]) {
      expect(resolveStyleSource(value)).toEqual({ kind: "file", value });
    }
  });
  it.each([
    "http://tiles.openfreemap.org/styles/liberty", "https://example.com/style.json",
    "https://tiles.openfreemap.org.evil.com/style", "https://tiles.openfreemap.org:444/style",
    "https://user@tiles.openfreemap.org/style", "https://:password@tiles.openfreemap.org/style",
    "file:///tmp/style.json", "//example.com/style.json",
  ])("rejects other URL sources %s", (source) => {
    expect(() => resolveStyleSource(source)).toThrow();
  });
});
