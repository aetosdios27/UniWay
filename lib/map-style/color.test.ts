import { describe, expect, it } from "vitest";
import {
  contrastRatio,
  formatHex,
  formatHsl,
  hslToRgb,
  isColorString,
  parseColor,
  relativeLuminance,
  rgbToHsl,
  toCanonicalColor,
  tryParseColor,
} from "./color";

describe("color utilities", () => {
  describe("parseColor", () => {
    it("parses 3-digit hex colors", () => {
      const c = parseColor("#fc8");
      // #ffcc88
      expect(c.h).toBeCloseTo(34.29, 1);
      expect(c.s).toBeCloseTo(100, 1);
      expect(c.l).toBeCloseTo(76.67, 1);
      expect(c.a).toBe(1);

      const white = parseColor("#fff");
      expect(white.l).toBe(100);
      expect(white.a).toBe(1);

      const black = parseColor("#000");
      expect(black.l).toBe(0);
      expect(black.a).toBe(1);
    });

    it("parses 4-digit hex colors with alpha", () => {
      const c = parseColor("#fc88");
      expect(c.a).toBeCloseTo(0.5333, 2);
    });

    it("parses 6-digit hex colors", () => {
      const c = parseColor("#f8f4f0");
      expect(c.a).toBe(1);
      const hex = formatHex(c);
      expect(hex).toBe("#f8f4f0");

      const dee = parseColor("#DEE3CD");
      expect(formatHex(dee)).toBe("#dee3cd");
    });

    it("parses 8-digit hex colors with alpha", () => {
      const c = parseColor("#1E273666");
      expect(c.a).toBeCloseTo(0.4, 1);
    });

    it("parses rgb colors (standard comma and space syntax)", () => {
      const c1 = parseColor("rgb(158, 189, 255)");
      expect(c1.a).toBe(1);
      const rgb1 = hslToRgb(c1.h, c1.s, c1.l);
      expect(rgb1.r).toBe(158);
      expect(rgb1.g).toBe(189);
      expect(rgb1.b).toBe(255);

      const c2 = parseColor("rgb(236,238,204)");
      const rgb2 = hslToRgb(c2.h, c2.s, c2.l);
      expect(rgb2.r).toBe(236);
      expect(rgb2.g).toBe(238);
      expect(rgb2.b).toBe(204);

      const c3 = parseColor("rgb(100% 0% 0%)");
      const rgb3 = hslToRgb(c3.h, c3.s, c3.l);
      expect(rgb3.r).toBe(255);
      expect(rgb3.g).toBe(0);
      expect(rgb3.b).toBe(0);
    });

    it("parses rgba colors with alpha numbers and percentages", () => {
      const c1 = parseColor("rgba(176, 213, 154, 1)");
      expect(c1.a).toBe(1);

      const c2 = parseColor("rgba(255, 255, 255, 0.7)");
      expect(c2.a).toBe(0.7);

      const c3 = parseColor("rgba(0 0 0 / 50%)");
      expect(c3.a).toBe(0.5);
    });

    it("parses hsl and hsla colors", () => {
      const c1 = parseColor("hsl(75, 37%, 81%)");
      expect(c1.h).toBe(75);
      expect(c1.s).toBe(37);
      expect(c1.l).toBe(81);
      expect(c1.a).toBe(1);

      const c2 = parseColor("hsla(0, 3%, 85%, 0.84)");
      expect(c2.h).toBe(0);
      expect(c2.s).toBe(3);
      expect(c2.l).toBe(85);
      expect(c2.a).toBe(0.84);

      const c3 = parseColor("hsla(35, 57%, 88%, 0.49)");
      expect(c3.h).toBe(35);
      expect(c3.s).toBe(57);
      expect(c3.l).toBe(88);
      expect(c3.a).toBe(0.49);

      const c4 = parseColor("hsl(180deg 50% 50% / 0.5)");
      expect(c4.h).toBe(180);
      expect(c4.a).toBe(0.5);
    });

    it("parses named colors", () => {
      const white = parseColor("white");
      expect(white.l).toBe(100);
      expect(white.a).toBe(1);

      const black = parseColor("black");
      expect(black.l).toBe(0);
      expect(black.a).toBe(1);

      const trans = parseColor("transparent");
      expect(trans.a).toBe(0);
    });

    it("throws a clear error on invalid colors", () => {
      expect(() => parseColor("")).toThrow(/Invalid color/);
      expect(() => parseColor("not-a-color")).toThrow(/Invalid color/);
      expect(() => parseColor("#12")).toThrow(/Invalid color/);
      expect(() => parseColor("#12345")).toThrow(/Invalid color/);
      expect(() => parseColor("rgb(1, 2)")).toThrow(/Invalid color/);
      expect(() => parseColor("hsl(abc, 50%, 50%)")).toThrow(/Invalid/);
    });

    it("correctly identifies valid and invalid color strings", () => {
      expect(isColorString("#fc8")).toBe(true);
      expect(isColorString("rgb(1, 2, 3)")).toBe(true);
      expect(isColorString("hsla(0, 0%, 0%, 0.5)")).toBe(true);
      expect(isColorString("white")).toBe(true);
      expect(isColorString("motorway")).toBe(false);
      expect(isColorString("interpolate")).toBe(false);
      expect(isColorString("zoom")).toBe(false);
      expect(isColorString(123)).toBe(false);
      expect(isColorString(null)).toBe(false);
      expect(tryParseColor("unknown")).toBeNull();
    });

    it("parses all 44 distinct liberty color literals without errors", () => {
      const libertyColors = [
        "#000",
        "#2e5a80",
        "#333",
        "#495e91",
        "#666",
        "#74aee9",
        "#DEE3CD",
        "#a0c8f0",
        "#bbb",
        "#cfcdca",
        "#d8e8c8",
        "#e9ac77",
        "#f0ede9",
        "#f8f4f0",
        "#fc8",
        "#fde",
        "#fea",
        "#ffdaa6",
        "#fff",
        "#fff4c6",
        "#ffffff",
        "hsl(0,0%,100%)",
        "hsl(0,0%,70%)",
        "hsl(248,1%,41%)",
        "hsl(26,87%,62%)",
        "hsl(30,23%,62%)",
        "hsl(35,6%,79%)",
        "hsl(35,6%,80%)",
        "hsl(35,8%,85%)",
        "hsl(36,6%,74%)",
        "hsl(75,37%,81%)",
        "hsla(0,3%,85%,0.84)",
        "hsla(35,57%,88%,0.49)",
        "hsla(35,6%,79%,0.32)",
        "hsla(98,61%,72%,0.7)",
        "rgb(158,189,255)",
        "rgb(236,238,204)",
        "rgba(176, 213, 154, 1)",
        "rgba(224, 236, 236, 1)",
        "rgba(228, 241, 215, 1)",
        "rgba(229, 228, 224, 1)",
        "rgba(247, 239, 195, 1)",
        "rgba(255,255,255,0.7)",
        "rgba(95, 208, 100, 1)",
      ];

      for (const col of libertyColors) {
        const parsed = parseColor(col);
        expect(parsed.h).toBeGreaterThanOrEqual(0);
        expect(parsed.h).toBeLessThan(360);
        expect(parsed.s).toBeGreaterThanOrEqual(0);
        expect(parsed.s).toBeLessThanOrEqual(100);
        expect(parsed.l).toBeGreaterThanOrEqual(0);
        expect(parsed.l).toBeLessThanOrEqual(100);
        expect(parsed.a).toBeGreaterThan(0);
        expect(parsed.a).toBeLessThanOrEqual(1);
      }
    });
  });

  describe("conversions and round-trips", () => {
    it("round-trips rgb <-> hsl accurately", () => {
      const testRgb = [
        { r: 255, g: 0, b: 0 },
        { r: 0, g: 255, b: 0 },
        { r: 0, g: 0, b: 255 },
        { r: 128, g: 128, b: 128 },
        { r: 14, g: 20, b: 32 },
        { r: 214, g: 221, b: 235 },
      ];

      for (const orig of testRgb) {
        const hsl = rgbToHsl(orig.r, orig.g, orig.b);
        const back = hslToRgb(hsl.h, hsl.s, hsl.l);
        expect(Math.abs(back.r - orig.r)).toBeLessThanOrEqual(1);
        expect(Math.abs(back.g - orig.g)).toBeLessThanOrEqual(1);
        expect(Math.abs(back.b - orig.b)).toBeLessThanOrEqual(1);
      }
    });

    it("formats canonical color string (#rrggbb for opaque, hsla for alpha)", () => {
      expect(toCanonicalColor({ h: 215, s: 39, l: 11, a: 1 })).toBe("#111a27");
      expect(toCanonicalColor({ h: 215, s: 39, l: 11, a: 0.84 })).toBe("hsla(215, 39%, 11%, 0.84)");
      expect(toCanonicalColor({ r: 14, g: 20, b: 32, a: 1 })).toBe("#0e1420");
      expect(formatHsl({ h: 30, s: 20, l: 50, a: 1 })).toBe("hsl(30, 20%, 50%)");
      expect(formatHsl({ h: 30, s: 20, l: 50, a: 0.5 })).toBe("hsla(30, 20%, 50%, 0.5)");
    });
  });

  describe("WCAG relative luminance and contrast ratio", () => {
    it("computes standard relative luminance", () => {
      expect(relativeLuminance("#000000")).toBe(0);
      expect(relativeLuminance("#ffffff")).toBeCloseTo(1, 4);
      // UniWay background
      const bgLum = relativeLuminance("#0E1420");
      expect(bgLum).toBeLessThan(0.02);
      expect(bgLum).toBeGreaterThan(0);
    });

    it("computes WCAG contrast ratio", () => {
      expect(contrastRatio("#ffffff", "#000000")).toBeCloseTo(21, 1);
      expect(contrastRatio("#ffffff", "#ffffff")).toBe(1);

      // Contrast against #0E1420
      const bg = "#0E1420";
      expect(contrastRatio("#D6DDEB", bg)).toBeGreaterThanOrEqual(4.5);
      expect(contrastRatio("#9AA7BD", bg)).toBeGreaterThanOrEqual(4.5);
      expect(contrastRatio("#6C9BCB", bg)).toBeGreaterThanOrEqual(4.5);
    });
  });
});
