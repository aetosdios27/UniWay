import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { POI_ICON_FALLBACK, POI_ICON_KEYS, PoiIconKeySchema } from "./poi-icons";

const config = JSON.parse(readFileSync("data/poi-icon-keys.json", "utf8"));

describe("poi-icons", () => {
  it("matches data/poi-icon-keys.json exactly", () => {
    expect([...POI_ICON_KEYS]).toEqual(config.keys);
    expect(POI_ICON_FALLBACK).toEqual(config.fallback);
    expect(POI_ICON_KEYS).toContain(POI_ICON_FALLBACK);
  });

  it("accepts valid icon keys", () => {
    for (const key of POI_ICON_KEYS) {
      expect(PoiIconKeySchema.parse(key)).toBe(key);
    }
  });

  it("rejects unknown icon key with a clear message listing allowed keys", () => {
    const result = PoiIconKeySchema.safeParse("unknown_icon");
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toContain("Invalid icon_key");
      expect(result.error.issues[0].message).toContain(POI_ICON_KEYS.join(", "));
    }
  });
});
