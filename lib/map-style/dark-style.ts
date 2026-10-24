/**
 * Dark map style generator for UniWay.
 *
 * Deterministically transforms a MapLibre style (e.g. OpenFreeMap Liberty)
 * into a dark theme with high contrast labels, subdued landcovers,
 * readable road hierarchies, and dark raster shading.
 */

import {
  isColorString,
  parseColor,
  toCanonicalColor,
  type HslColor,
} from "./color";

export interface StyleOverride {
  /** Regular expression tested against layer.id */
  idPattern: RegExp;
  /** Optional property name or regex to match specific paint property */
  propertyPattern?: RegExp | string;
  /** Replacement color hex/hsl or transformer callback */
  color:
    | string
    | ((
        orig: HslColor,
        prop: string,
        layerId: string,
        layerType: string
      ) => string | HslColor);
}

export interface DarkenStyleOptions {
  /** Optional overrides prepended before default role overrides */
  overrides?: StyleOverride[];
  /** Style name. Defaults to "UniWay Dark". */
  name?: string;
  /** Metadata to merge. Defaults to uniway:derivedFrom: liberty, uniway:generator: build-dark-style. */
  metadata?: Record<string, unknown>;
  /** Raster brightness max for raster layers. Defaults to 0.18. */
  rasterBrightnessMax?: number;
  /** Raster saturation for raster layers. Defaults to -0.5. */
  rasterSaturation?: number;
}

/**
 * Transforms an HSL color according to generic layer-type and property dark rules.
 *
 * - Keeps original hue
 * - Reduces saturation by ~35%
 * - Maps lightness from light -> dark
 * - Preserves alpha
 */
export function genericDarkenColor(
  orig: HslColor,
  prop: string,
  layerId: string,
  layerType: string
): HslColor {
  const h = orig.h;
  const s = Math.max(0, Math.min(100, Math.round(orig.s * 0.65 * 100) / 100));
  const a = orig.a;
  const L = orig.l / 100;

  let LPrime: number;
  if (prop === "background-color" || layerType === "background") {
    LPrime = 0.06 + (1 - L) * 0.04;
  } else if (
    prop === "fill-color" ||
    prop === "fill-extrusion-color" ||
    layerType === "fill" ||
    layerType === "fill-extrusion"
  ) {
    LPrime = 0.07 + (1 - L) * 0.22;
  } else if (
    prop === "line-color" ||
    prop === "fill-outline-color" ||
    layerType === "line"
  ) {
    const isCasing =
      layerId.includes("casing") ||
      layerId.includes("outline") ||
      prop === "fill-outline-color";
    if (isCasing) {
      // Casings reversed (darker than road fills)
      LPrime = 0.05 + L * 0.05;
    } else {
      LPrime = 0.16 + (1 - L) * 0.3;
    }
  } else if (prop === "text-color") {
    LPrime = Math.min(0.92, 0.62 + (1 - L) * 0.3);
  } else if (prop === "text-halo-color") {
    LPrime = Math.min(0.12, 0.05 + (1 - L) * 0.06);
  } else {
    LPrime = 0.1 + (1 - L) * 0.2;
  }

  const l = Math.max(0, Math.min(100, Math.round(LPrime * 10000) / 100));
  return {
    h: Math.round(h * 100) / 100,
    s,
    l,
    a,
  };
}

function withPreservedAlpha(targetHex: string, orig: HslColor): HslColor {
  const parsed = parseColor(targetHex);
  return {
    ...parsed,
    a: orig.a,
  };
}

/**
 * Built-in UniWay Dark role table matching layer IDs and properties to target colors.
 */
export const DEFAULT_STYLE_OVERRIDES: StyleOverride[] = [
  // 1. Background
  {
    idPattern: /^background$/,
    propertyPattern: "background-color",
    color: "#0E1420",
  },

  // 2. Residential landuse
  {
    idPattern: /^landuse_residential$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#111A27", orig),
  },

  // 3. Parks and landcover
  {
    idPattern: /^park$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#14261A", orig),
  },
  {
    idPattern: /^park$/,
    propertyPattern: "fill-outline-color",
    color: "#14261A",
  },
  {
    idPattern: /^park_outline$/,
    propertyPattern: "line-color",
    color: "#14261A",
  },
  {
    idPattern: /^landcover_grass$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#14261A", orig),
  },
  {
    idPattern: /^landcover_wood$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#12251B", orig),
  },
  {
    idPattern: /^landcover_wetland$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#12261F", orig),
  },
  {
    idPattern: /^landcover_(ice|sand)$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#1E2530", orig),
  },
  {
    idPattern: /^landuse_pitch$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#18301F", orig),
  },
  {
    idPattern: /^landuse_track$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#1A2A22", orig),
  },
  {
    idPattern: /^landuse_cemetery$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#15231C", orig),
  },
  {
    idPattern: /^landuse_hospital$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#2A1D24", orig),
  },
  {
    idPattern: /^landuse_school$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#1C1B2B", orig),
  },

  // 4. Water and waterways
  {
    idPattern: /^water$/,
    propertyPattern: "fill-color",
    color: (orig) => withPreservedAlpha("#0B2740", orig),
  },
  {
    idPattern: /^waterway_tunnel$/,
    propertyPattern: "line-color",
    color: "#081E31",
  },
  {
    idPattern: /^waterway_/,
    propertyPattern: "line-color",
    color: "#0B2740",
  },

  // 5. Buildings
  {
    idPattern: /^building$/,
    propertyPattern: "fill-color",
    color: "#1B2432",
  },
  {
    idPattern: /^building$/,
    propertyPattern: "fill-outline-color",
    // interpolate zoom 13 -> #1E2736 alpha 0.4, zoom 14 -> #2A3548
    color: (orig) => {
      if (orig.a < 0.5) {
        return { ...parseColor("#1E2736"), a: 0.4 };
      }
      return "#2A3548";
    },
  },
  {
    idPattern: /^building-3d$/,
    propertyPattern: "fill-extrusion-color",
    color: "#202A3B",
  },

  // 6. Road casings
  {
    idPattern: /^(road|bridge)_motorway_casing$/,
    propertyPattern: "line-color",
    color: "#231A0B",
  },
  {
    idPattern: /^tunnel_motorway_casing$/,
    propertyPattern: "line-color",
    color: "#1B1408",
  },
  {
    idPattern: /^tunnel_.*_casing$/,
    propertyPattern: "line-color",
    color: "#060A10",
  },
  {
    idPattern: /^(road|bridge)_.*_casing$/,
    propertyPattern: "line-color",
    color: "#0A0F18",
  },

  // 7. Road fills
  {
    idPattern: /^(road|bridge)_path_pedestrian$/,
    propertyPattern: "line-color",
    color: "#353F52",
  },
  {
    idPattern: /^tunnel_path_pedestrian$/,
    propertyPattern: "line-color",
    color: "#2C3545",
  },
  {
    idPattern: /^(road|bridge)_motorway$/,
    propertyPattern: "line-color",
    color: "#5A4A2A",
  },
  {
    idPattern: /^tunnel_motorway$/,
    propertyPattern: "line-color",
    color: "#473A21",
  },
  {
    idPattern: /^(road|bridge)_motorway_link$/,
    propertyPattern: "line-color",
    color: "#5A4A2A",
  },
  {
    idPattern: /^tunnel_motorway_link$/,
    propertyPattern: "line-color",
    color: "#473A21",
  },
  {
    idPattern: /^(road|bridge)_trunk_primary$/,
    propertyPattern: "line-color",
    color: "#3D4A66",
  },
  {
    idPattern: /^tunnel_trunk_primary$/,
    propertyPattern: "line-color",
    color: "#303B52",
  },
  {
    idPattern: /^(road|bridge)_secondary_tertiary$/,
    propertyPattern: "line-color",
    color: "#343F55",
  },
  {
    idPattern: /^tunnel_secondary_tertiary$/,
    propertyPattern: "line-color",
    color: "#2A3345",
  },
  {
    idPattern: /^(road|bridge)_(minor|street|service_track|link)$/,
    propertyPattern: "line-color",
    color: "#2B3547",
  },
  {
    idPattern: /^tunnel_(minor|street|service_track|link)$/,
    propertyPattern: "line-color",
    color: "#232B3A",
  },

  // 8. Rail
  {
    idPattern: /^tunnel_(major|transit)_rail.*$/,
    propertyPattern: "line-color",
    color: "#2E3545",
  },
  {
    idPattern: /^(road|bridge)_(major|transit)_rail.*$/,
    propertyPattern: "line-color",
    color: "#3A4256",
  },

  // 9. Aeroway
  {
    idPattern: /^aeroway_/,
    propertyPattern: /^(fill|line)-color$/,
    color: (orig) => withPreservedAlpha("#232C3C", orig),
  },

  // 10. Boundaries
  {
    idPattern: /^boundary_/,
    propertyPattern: "line-color",
    color: (orig) => withPreservedAlpha("#3A4660", orig),
  },

  // 11. Labels
  {
    idPattern: /^label_/,
    propertyPattern: "text-color",
    color: "#D6DDEB",
  },
  {
    idPattern: /^label_/,
    propertyPattern: "text-halo-color",
    color: (orig) => withPreservedAlpha("#0E1420", orig),
  },
  {
    idPattern: /^highway-name-/,
    propertyPattern: "text-color",
    color: "#9AA7BD",
  },
  {
    idPattern: /^highway-name-/,
    propertyPattern: "text-halo-color",
    color: (orig) => withPreservedAlpha("#0E1420", orig),
  },
  {
    idPattern: /^(waterway_line_label|water_name_.*)$/,
    propertyPattern: "text-color",
    color: "#6C9BCB",
  },
  {
    idPattern: /^(waterway_line_label|water_name_.*)$/,
    propertyPattern: "text-halo-color",
    color: (orig) => withPreservedAlpha("#0B2740", orig),
  },
  {
    idPattern: /^(poi_.*|airport)$/,
    propertyPattern: "text-color",
    color: "#9AA7BD",
  },
  {
    idPattern: /^(poi_.*|airport)$/,
    propertyPattern: "text-halo-color",
    color: (orig) => withPreservedAlpha("#0E1420", orig),
  },
];

/**
 * Resolves the rewritten dark color for a given color literal in a layer paint property.
 */
function resolveDarkColor(
  rawColorStr: string,
  layerId: string,
  layerType: string,
  paintProp: string,
  overrides: StyleOverride[]
): string {
  const orig = parseColor(rawColorStr);

  for (const rule of overrides) {
    if (!rule.idPattern.test(layerId)) continue;
    if (rule.propertyPattern) {
      if (typeof rule.propertyPattern === "string") {
        if (rule.propertyPattern !== paintProp) continue;
      } else if (!rule.propertyPattern.test(paintProp)) {
        continue;
      }
    }

    const transformed =
      typeof rule.color === "function"
        ? rule.color(orig, paintProp, layerId, layerType)
        : rule.color;

    if (typeof transformed === "string") {
      return transformed;
    }
    return toCanonicalColor(transformed);
  }

  // Fallback to generic rule
  const generic = genericDarkenColor(orig, paintProp, layerId, layerType);
  return toCanonicalColor(generic);
}

/**
 * Recursively walks a paint property value (expressions, arrays, objects) and rewrites color literals.
 */
function rewritePaintValue(
  value: unknown,
  layerId: string,
  layerType: string,
  paintProp: string,
  overrides: StyleOverride[]
): unknown {
  if (typeof value === "string") {
    if (isColorString(value)) {
      return resolveDarkColor(value, layerId, layerType, paintProp, overrides);
    }
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) =>
      rewritePaintValue(item, layerId, layerType, paintProp, overrides)
    );
  }

  if (value !== null && typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value)) {
      result[k] = rewritePaintValue(v, layerId, layerType, paintProp, overrides);
    }
    return result;
  }

  return value;
}

/**
 * Pure, deterministic transformer from a MapLibre style specification to UniWay Dark.
 *
 * Input style is not mutated. Output is byte-identical across runs.
 */
export function darkenStyle<T extends { layers?: unknown[]; name?: string; metadata?: Record<string, unknown> }>(
  style: T,
  options: DarkenStyleOptions = {}
): T {
  // Deep clone to guarantee input is never mutated
  const cloned = JSON.parse(JSON.stringify(style)) as T;

  const overrides: StyleOverride[] = [
    ...(options.overrides ?? []),
    ...DEFAULT_STYLE_OVERRIDES,
  ];

  cloned.name = options.name ?? "UniWay Dark";
  cloned.metadata = {
    ...(cloned.metadata ?? {}),
    "uniway:derivedFrom": "liberty",
    "uniway:generator": "build-dark-style",
    ...(options.metadata ?? {}),
  };

  const layers = Array.isArray(cloned.layers) ? cloned.layers : [];

  for (const rawLayer of layers) {
    if (rawLayer === null || typeof rawLayer !== "object") continue;
    const layer = rawLayer as Record<string, unknown>;
    const layerId = String(layer.id ?? "");
    const layerType = String(layer.type ?? "");

    // Raster layer handling: darken via raster properties rather than recolouring
    if (layerId === "natural_earth" || layerType === "raster") {
      const paint = (layer.paint && typeof layer.paint === "object"
        ? (layer.paint as Record<string, unknown>)
        : {}) as Record<string, unknown>;

      layer.paint = {
        ...paint,
        "raster-brightness-max": options.rasterBrightnessMax ?? 0.18,
        "raster-saturation": options.rasterSaturation ?? -0.5,
      };
      continue;
    }

    if (!layer.paint || typeof layer.paint !== "object") continue;
    const paint = layer.paint as Record<string, unknown>;

    for (const [propName, propValue] of Object.entries(paint)) {
      paint[propName] = rewritePaintValue(
        propValue,
        layerId,
        layerType,
        propName,
        overrides
      );
    }
  }

  return cloned;
}
