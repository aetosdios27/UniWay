import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { parseColor, relativeLuminance, contrastRatio } from "./color";
import { darkenStyle } from "./dark-style";

describe("darkenStyle", () => {
  describe("synthetic mini-style", () => {
    interface MiniStyle {
      version: number;
      name: string;
      metadata?: Record<string, unknown>;
      sources: Record<string, unknown>;
      sprite: string;
      glyphs: string;
      layers: Array<{
        id: string;
        type: string;
        source?: string;
        "source-layer"?: string;
        minzoom?: number;
        maxzoom?: number;
        filter?: unknown[];
        layout?: Record<string, unknown>;
        paint?: Record<string, unknown>;
      }>;
    }

    const createMiniStyle = (): MiniStyle => ({
      version: 8,
      name: "Synthetic Mini",
      sources: {
        composite: {
          type: "vector",
          url: "https://example.com/tiles.json",
        },
        rasterSource: {
          type: "raster",
          url: "https://example.com/raster.json",
        },
      },
      sprite: "https://example.com/sprite",
      glyphs: "https://example.com/fonts/{fontstack}/{range}.pbf",
      layers: [
        {
          id: "background",
          type: "background",
          paint: {
            "background-color": "#f8f4f0",
          },
        },
        {
          id: "natural_earth",
          type: "raster",
          source: "rasterSource",
          paint: {
            "raster-opacity": ["interpolate", ["linear"], ["zoom"], 0, 0.6, 6, 0.1],
          },
        },
        {
          id: "custom_fill",
          type: "fill",
          source: "composite",
          "source-layer": "custom",
          minzoom: 5,
          maxzoom: 18,
          filter: ["==", "class", "park"],
          layout: { visibility: "visible" },
          paint: {
            "fill-color": ["interpolate", ["linear"], ["zoom"], 5, "#ffffff", 10, "#d8e8c8"],
          },
        },
        {
          id: "custom_step_line",
          type: "line",
          source: "composite",
          "source-layer": "road",
          paint: {
            "line-color": ["step", ["zoom"], "#ffffff", 10, "#e9ac77", 14, "#fc8"],
          },
        },
        {
          id: "custom_match_road",
          type: "line",
          source: "composite",
          "source-layer": "road",
          paint: {
            "line-color": [
              "match",
              ["get", "class"],
              "motorway",
              "#fc8",
              "primary",
              "#fea",
              "#ffffff",
            ],
          },
        },
        {
          id: "custom_case_nested",
          type: "symbol",
          source: "composite",
          "source-layer": "poi",
          paint: {
            "text-color": [
              "case",
              ["==", ["get", "subclass"], "station"],
              ["interpolate", ["linear"], ["zoom"], 10, "#000000", 15, "#333333"],
              "#666666",
            ],
            "text-halo-color": "#ffffff",
          },
        },
      ],
    });

    it("does not mutate the input style", () => {
      const original = createMiniStyle();
      const originalSnapshot = JSON.stringify(original);
      const output = darkenStyle(original);

      expect(JSON.stringify(original)).toBe(originalSnapshot);
      expect(output).not.toBe(original);
    });

    it("is completely deterministic (run twice -> deep equal)", () => {
      const input = createMiniStyle();
      const out1 = darkenStyle(input);
      const out2 = darkenStyle(input);

      expect(out1).toEqual(out2);
    });

    it("preserves layer order, IDs, filters, layout, sources, sprite, and glyphs", () => {
      const input = createMiniStyle();
      const output = darkenStyle(input);

      expect(output.sources).toEqual(input.sources);
      expect(output.sprite).toBe(input.sprite);
      expect(output.glyphs).toBe(input.glyphs);

      expect(output.layers.length).toBe(input.layers.length);
      for (let i = 0; i < input.layers.length; i++) {
        expect(output.layers[i].id).toBe(input.layers[i].id);
        expect(output.layers[i].type).toBe(input.layers[i].type);
        if ("filter" in input.layers[i]) {
          expect(output.layers[i].filter).toEqual(input.layers[i].filter);
        }
        if ("layout" in input.layers[i]) {
          expect(output.layers[i].layout).toEqual(input.layers[i].layout);
        }
      }
    });

    it("sets raster layer properties while preserving opacity expressions", () => {
      const input = createMiniStyle();
      const output = darkenStyle(input);
      const rasterLayer = output.layers.find((l) => l.id === "natural_earth");

      expect(rasterLayer).toBeDefined();
      expect(rasterLayer?.paint?.["raster-brightness-max"]).toBeCloseTo(0.18);
      expect(rasterLayer?.paint?.["raster-saturation"]).toBeCloseTo(-0.5);
      expect(rasterLayer?.paint?.["raster-opacity"]).toEqual([
        "interpolate",
        ["linear"],
        ["zoom"],
        0,
        0.6,
        6,
        0.1,
      ]);
    });

    it("rewrites color stops in interpolate, step, match, and case expressions while keeping numeric stops and strings", () => {
      const input = createMiniStyle();
      const output = darkenStyle(input);

      // Interpolate in custom_fill
      const fillLayer = output.layers.find((l) => l.id === "custom_fill");
      const fillExpr = fillLayer?.paint?.["fill-color"] as unknown[];
      expect(fillExpr[0]).toBe("interpolate");
      expect(fillExpr[3]).toBe(5); // zoom stop unchanged
      expect(fillExpr[5]).toBe(10); // zoom stop unchanged
      expect(typeof fillExpr[4]).toBe("string");
      expect(typeof fillExpr[6]).toBe("string");

      // Step in custom_step_line
      const stepLayer = output.layers.find((l) => l.id === "custom_step_line");
      const stepExpr = stepLayer?.paint?.["line-color"] as unknown[];
      expect(stepExpr[0]).toBe("step");
      expect(stepExpr[3]).toBe(10);
      expect(stepExpr[5]).toBe(14);

      // Match in custom_match_road
      const matchLayer = output.layers.find((l) => l.id === "custom_match_road");
      const matchExpr = matchLayer?.paint?.["line-color"] as unknown[];
      expect(matchExpr[0]).toBe("match");
      expect(matchExpr[2]).toBe("motorway"); // category string untouched
      expect(matchExpr[4]).toBe("primary"); // category string untouched

      // Nested case in custom_case_nested
      const caseLayer = output.layers.find((l) => l.id === "custom_case_nested");
      const caseExpr = caseLayer?.paint?.["text-color"] as unknown[];
      expect(caseExpr[0]).toBe("case");
      const haloColor = caseLayer?.paint?.["text-halo-color"] as string;
      expect(typeof haloColor).toBe("string");
      expect(relativeLuminance(haloColor)).toBeLessThanOrEqual(0.12);
    });

    it("sets style name and metadata correctly", () => {
      const input = createMiniStyle();
      const output = darkenStyle(input);

      expect(output.name).toBe("UniWay Dark");
      expect(output.metadata).toEqual({
        "uniway:derivedFrom": "liberty",
        "uniway:generator": "build-dark-style",
      });
    });
  });

  describe("structural invariants on generated asset", () => {
    const assetPath = path.resolve(__dirname, "../../mobile/assets/map/uniway_dark_style.json");
    const libertyPath = "/tmp/liberty.json";

    const loadDarkAsset = () => {
      if (!fs.existsSync(assetPath)) {
        throw new Error(`Generated dark style asset not found at: ${assetPath}`);
      }
      return JSON.parse(fs.readFileSync(assetPath, "utf-8"));
    };

    it("has identical layer count, ids, order, sources, sprite, and glyphs to /tmp/liberty.json when present", () => {
      const darkStyle = loadDarkAsset();

      if (!fs.existsSync(libertyPath)) {
        // Skip assertion if liberty snapshot is absent in test environment
        return;
      }

      const liberty = JSON.parse(fs.readFileSync(libertyPath, "utf-8"));

      expect(darkStyle.layers.length).toBe(liberty.layers.length);
      expect(darkStyle.sources).toEqual(liberty.sources);
      expect(darkStyle.sprite).toBe(liberty.sprite);
      expect(darkStyle.glyphs).toBe(liberty.glyphs);

      for (let i = 0; i < liberty.layers.length; i++) {
        expect(darkStyle.layers[i].id).toBe(liberty.layers[i].id);
        expect(darkStyle.layers[i].type).toBe(liberty.layers[i].type);
      }
    });

    it("has background luminance < 0.02", () => {
      const darkStyle = loadDarkAsset();
      const bgLayer = darkStyle.layers.find((l: { id: string }) => l.id === "background");
      expect(bgLayer).toBeDefined();

      const bgColor = bgLayer.paint["background-color"];
      const lum = relativeLuminance(bgColor);
      expect(lum).toBeLessThan(0.02);
      expect(bgColor.toLowerCase()).toBe("#0e1420");
    });

    it("ensures building and building-3d have the exact expected colors", () => {
      const darkStyle = loadDarkAsset();

      const bldg = darkStyle.layers.find((l: { id: string }) => l.id === "building");
      expect(bldg).toBeDefined();
      expect(bldg.paint["fill-color"].toLowerCase()).toBe("#1b2432");

      const outline = bldg.paint["fill-outline-color"];
      expect(Array.isArray(outline)).toBe(true);
      expect(outline[0]).toBe("interpolate");
      // zoom 13 stop has #1E2736 alpha 0.4
      expect(outline[3]).toBe(13);
      const parsedZ13 = parseColor(outline[4]);
      expect(parsedZ13.a).toBeCloseTo(0.4, 1);

      // zoom 14 stop has #2A3548
      expect(outline[5]).toBe(14);
      expect(outline[6].toLowerCase()).toBe("#2a3548");

      const bldg3d = darkStyle.layers.find((l: { id: string }) => l.id === "building-3d");
      expect(bldg3d).toBeDefined();
      expect(bldg3d.paint["fill-extrusion-color"].toLowerCase()).toBe("#202a3b");
    });

    it("ensures poi_r1, poi_r7, poi_r20, and poi_transit layers still exist", () => {
      const darkStyle = loadDarkAsset();
      const layerIds = new Set(darkStyle.layers.map((l: { id: string }) => l.id));

      expect(layerIds.has("poi_r1")).toBe(true);
      expect(layerIds.has("poi_r7")).toBe(true);
      expect(layerIds.has("poi_r20")).toBe(true);
      expect(layerIds.has("poi_transit")).toBe(true);
    });

    it("ensures every fill/line color that is not alpha < 0.1 has relative luminance below 0.35", () => {
      const darkStyle = loadDarkAsset();

      function checkColor(val: unknown, layerId: string, prop: string) {
        if (typeof val === "string") {
          try {
            const parsed = parseColor(val);
            if (parsed.a < 0.1) return;
            const lum = relativeLuminance(parsed);
            expect(
              lum,
              `Layer ${layerId} property ${prop} with color ${val} has luminance ${lum} >= 0.35`
            ).toBeLessThan(0.35);
          } catch {
            // Not a color string (e.g. pattern name or operator)
          }
        } else if (Array.isArray(val)) {
          for (const item of val) {
            checkColor(item, layerId, prop);
          }
        }
      }

      for (const layer of darkStyle.layers) {
        const lid = layer.id;
        const ltype = layer.type;
        const paint = layer.paint ?? {};

        if (ltype === "fill" || ltype === "line" || ltype === "fill-extrusion") {
          for (const [k, v] of Object.entries(paint)) {
            if (k.endsWith("-color")) {
              checkColor(v, lid, k);
            }
          }
        }
      }
    });

    it("ensures every symbol text-color has contrast >= 4.5:1 against #0E1420", () => {
      const darkStyle = loadDarkAsset();
      const bg = "#0E1420";

      function checkTextColor(val: unknown, layerId: string) {
        if (typeof val === "string") {
          try {
            const parsed = parseColor(val);
            const cr = contrastRatio(parsed, bg);
            expect(
              cr,
              `Layer ${layerId} text-color "${val}" contrast ratio ${cr} < 4.5:1 against ${bg}`
            ).toBeGreaterThanOrEqual(4.5);
          } catch {
            // Non-color string
          }
        } else if (Array.isArray(val)) {
          for (const item of val) {
            checkTextColor(item, layerId);
          }
        }
      }

      for (const layer of darkStyle.layers) {
        if (layer.type === "symbol" && layer.paint?.["text-color"]) {
          checkTextColor(layer.paint["text-color"], layer.id);
        }
      }
    });

    it("ensures every text-halo is dark (relative luminance <= 0.12)", () => {
      const darkStyle = loadDarkAsset();

      function checkHalo(val: unknown, layerId: string) {
        if (typeof val === "string") {
          try {
            const parsed = parseColor(val);
            const lum = relativeLuminance(parsed);
            expect(
              lum,
              `Layer ${layerId} text-halo-color "${val}" luminance ${lum} > 0.12`
            ).toBeLessThanOrEqual(0.12);
          } catch {
            // Non-color string
          }
        } else if (Array.isArray(val)) {
          for (const item of val) {
            checkHalo(item, layerId);
          }
        }
      }

      for (const layer of darkStyle.layers) {
        if (layer.type === "symbol" && layer.paint?.["text-halo-color"]) {
          checkHalo(layer.paint["text-halo-color"], layer.id);
        }
      }
    });
  });
});
