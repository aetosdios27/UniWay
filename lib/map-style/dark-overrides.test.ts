import { describe, expect, it } from "vitest";
import { isColorString } from "./color";
import { DEFAULT_STYLE_OVERRIDES } from "./dark-style";

const SOURCE = { h: 120, s: 50, l: 50, a: 0.7 };

describe("DEFAULT_STYLE_OVERRIDES", () => {
  const transformers = DEFAULT_STYLE_OVERRIDES.flatMap((override) =>
    typeof override.color === "function" ? [{ override, color: override.color }] : [],
  );

  it("has transformer roles to exercise", () => {
    expect(transformers.length).toBeGreaterThan(10);
  });

  it.each(transformers.map((t) => [String(t.override.idPattern), t.color] as const))(
    "%s returns a valid colour and keeps the source alpha",
    (_pattern, color) => {
      const result = color(SOURCE, "fill-color", "layer", "fill");

      if (typeof result === "string") {
        expect(isColorString(result)).toBe(true);
      } else {
        expect(result.a).toBe(SOURCE.a);
        expect(result.l).toBeLessThan(40);
      }
    },
  );

  it("makes low-zoom building outlines translucent and high-zoom ones solid", () => {
    const outline = DEFAULT_STYLE_OVERRIDES.find(
      (o) => o.idPattern.test("building") && o.propertyPattern === "fill-outline-color",
    );
    if (!outline || typeof outline.color !== "function") throw new Error("missing building outline role");

    const low = outline.color({ ...SOURCE, a: 0.3 }, "fill-outline-color", "building", "fill");
    const high = outline.color({ ...SOURCE, a: 1 }, "fill-outline-color", "building", "fill");

    expect(typeof low === "object" && low.a).toBe(0.4);
    expect(high).toBe("#2A3548");
  });
});
