/**
 * Pure color utilities for map style generation.
 *
 * Supports parsing CSS/MapLibre color formats (hex, rgb, rgba, hsl, hsla),
 * converting between RGB and HSL representations, formatting canonical output,
 * and computing WCAG relative luminance and contrast ratios.
 */

export interface HslColor {
  /** Hue in degrees [0, 360) */
  h: number;
  /** Saturation percentage [0, 100] */
  s: number;
  /** Lightness percentage [0, 100] */
  l: number;
  /** Alpha channel [0, 1] */
  a: number;
}

export interface RgbColor {
  /** Red component [0, 255] */
  r: number;
  /** Green component [0, 255] */
  g: number;
  /** Blue component [0, 255] */
  b: number;
  /** Alpha channel [0, 1] */
  a: number;
}

const NAMED_COLORS: Record<string, { r: number; g: number; b: number; a: number }> = {
  transparent: { r: 0, g: 0, b: 0, a: 0 },
  black: { r: 0, g: 0, b: 0, a: 1 },
  white: { r: 255, g: 255, b: 255, a: 1 },
};

/**
 * Converts RGB components to HSL representation.
 */
export function rgbToHsl(r: number, g: number, b: number, a = 1): HslColor {
  const rNorm = Math.max(0, Math.min(255, r)) / 255;
  const gNorm = Math.max(0, Math.min(255, g)) / 255;
  const bNorm = Math.max(0, Math.min(255, b)) / 255;

  const max = Math.max(rNorm, gNorm, bNorm);
  const min = Math.min(rNorm, gNorm, bNorm);
  const delta = max - min;
  const l = (max + min) / 2;

  let h = 0;
  let s = 0;

  if (delta !== 0) {
    s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);
    switch (max) {
      case rNorm:
        h = ((gNorm - bNorm) / delta + (gNorm < bNorm ? 6 : 0)) * 60;
        break;
      case gNorm:
        h = ((bNorm - rNorm) / delta + 2) * 60;
        break;
      case bNorm:
        h = ((rNorm - gNorm) / delta + 4) * 60;
        break;
    }
  }

  const clampedAlpha = Math.max(0, Math.min(1, a));
  return {
    h: Math.round(((h % 360) + 360) % 360 * 100) / 100,
    s: Math.round(s * 10000) / 100,
    l: Math.round(l * 10000) / 100,
    a: Math.round(clampedAlpha * 10000) / 10000,
  };
}

/**
 * Converts HSL components to RGB representation.
 */
export function hslToRgb(h: number, s: number, l: number, a = 1): RgbColor {
  const normalizedH = (((h % 360) + 360) % 360) / 60;
  const sNorm = Math.max(0, Math.min(100, s)) / 100;
  const lNorm = Math.max(0, Math.min(100, l)) / 100;

  const c = (1 - Math.abs(2 * lNorm - 1)) * sNorm;
  const x = c * (1 - Math.abs((normalizedH % 2) - 1));
  const m = lNorm - c / 2;

  let rNorm = 0;
  let gNorm = 0;
  let bNorm = 0;

  if (normalizedH >= 0 && normalizedH < 1) {
    rNorm = c;
    gNorm = x;
    bNorm = 0;
  } else if (normalizedH >= 1 && normalizedH < 2) {
    rNorm = x;
    gNorm = c;
    bNorm = 0;
  } else if (normalizedH >= 2 && normalizedH < 3) {
    rNorm = 0;
    gNorm = c;
    bNorm = x;
  } else if (normalizedH >= 3 && normalizedH < 4) {
    rNorm = 0;
    gNorm = x;
    bNorm = c;
  } else if (normalizedH >= 4 && normalizedH < 5) {
    rNorm = x;
    gNorm = 0;
    bNorm = c;
  } else {
    rNorm = c;
    gNorm = 0;
    bNorm = x;
  }

  return {
    r: Math.round((rNorm + m) * 255),
    g: Math.round((gNorm + m) * 255),
    b: Math.round((bNorm + m) * 255),
    a: Math.max(0, Math.min(1, Math.round(a * 10000) / 10000)),
  };
}

function parseAlphaToken(token: string): number {
  const trimmed = token.trim();
  if (trimmed.endsWith("%")) {
    const val = Number.parseFloat(trimmed.slice(0, -1));
    if (Number.isNaN(val)) throw new Error(`Invalid alpha percentage: ${token}`);
    return Math.max(0, Math.min(1, val / 100));
  }
  const val = Number.parseFloat(trimmed);
  if (Number.isNaN(val)) throw new Error(`Invalid alpha value: ${token}`);
  return Math.max(0, Math.min(1, val));
}

function parseHueToken(token: string): number {
  const trimmed = token.trim().toLowerCase();
  let degrees = 0;
  if (trimmed.endsWith("deg")) {
    degrees = Number.parseFloat(trimmed.slice(0, -3));
  } else if (trimmed.endsWith("turn")) {
    degrees = Number.parseFloat(trimmed.slice(0, -4)) * 360;
  } else if (trimmed.endsWith("rad")) {
    degrees = (Number.parseFloat(trimmed.slice(0, -3)) * 180) / Math.PI;
  } else {
    degrees = Number.parseFloat(trimmed);
  }
  if (Number.isNaN(degrees)) throw new Error(`Invalid hue: ${token}`);
  return ((degrees % 360) + 360) % 360;
}

function parsePercentageToken(token: string): number {
  const trimmed = token.trim();
  if (trimmed.endsWith("%")) {
    const val = Number.parseFloat(trimmed.slice(0, -1));
    if (Number.isNaN(val)) throw new Error(`Invalid percentage: ${token}`);
    return Math.max(0, Math.min(100, val));
  }
  const val = Number.parseFloat(trimmed);
  if (Number.isNaN(val)) throw new Error(`Invalid number: ${token}`);
  return Math.max(0, Math.min(100, val));
}

function parseRgbComponent(token: string): number {
  const trimmed = token.trim();
  if (trimmed.endsWith("%")) {
    const pct = Number.parseFloat(trimmed.slice(0, -1));
    if (Number.isNaN(pct)) throw new Error(`Invalid rgb percentage: ${token}`);
    return Math.max(0, Math.min(255, Math.round((pct / 100) * 255)));
  }
  const val = Number.parseFloat(trimmed);
  if (Number.isNaN(val)) throw new Error(`Invalid rgb number: ${token}`);
  return Math.max(0, Math.min(255, Math.round(val)));
}

/**
 * Parses any valid CSS / MapLibre color string into HslColor.
 * Throws a descriptive Error if the string cannot be parsed.
 */
export function parseColor(colorStr: string): HslColor {
  if (typeof colorStr !== "string" || !colorStr.trim()) {
    throw new Error(`Invalid color: "${String(colorStr)}"`);
  }

  const raw = colorStr.trim();
  const lower = raw.toLowerCase();

  // Named colors
  if (lower in NAMED_COLORS) {
    const nc = NAMED_COLORS[lower];
    return rgbToHsl(nc.r, nc.g, nc.b, nc.a);
  }

  // Hex colors: #rgb, #rgba, #rrggbb, #rrggbbaa
  if (raw.startsWith("#")) {
    const hex = raw.slice(1);
    let r = 0;
    let g = 0;
    let b = 0;
    let a = 1;

    if (!/^[0-9a-fA-F]+$/.test(hex)) {
      throw new Error(`Invalid color: "${colorStr}"`);
    }

    if (hex.length === 3) {
      r = Number.parseInt(hex[0] + hex[0], 16);
      g = Number.parseInt(hex[1] + hex[1], 16);
      b = Number.parseInt(hex[2] + hex[2], 16);
    } else if (hex.length === 4) {
      r = Number.parseInt(hex[0] + hex[0], 16);
      g = Number.parseInt(hex[1] + hex[1], 16);
      b = Number.parseInt(hex[2] + hex[2], 16);
      a = Number.parseInt(hex[3] + hex[3], 16) / 255;
    } else if (hex.length === 6) {
      r = Number.parseInt(hex.slice(0, 2), 16);
      g = Number.parseInt(hex.slice(2, 4), 16);
      b = Number.parseInt(hex.slice(4, 6), 16);
    } else if (hex.length === 8) {
      r = Number.parseInt(hex.slice(0, 2), 16);
      g = Number.parseInt(hex.slice(2, 4), 16);
      b = Number.parseInt(hex.slice(4, 6), 16);
      a = Number.parseInt(hex.slice(6, 8), 16) / 255;
    } else {
      throw new Error(`Invalid color: "${colorStr}"`);
    }

    return rgbToHsl(r, g, b, a);
  }

  // RGB / RGBA
  if (lower.startsWith("rgb(") || lower.startsWith("rgba(")) {
    const openParen = raw.indexOf("(");
    const closeParen = raw.lastIndexOf(")");
    if (openParen === -1 || closeParen === -1 || closeParen <= openParen) {
      throw new Error(`Invalid color: "${colorStr}"`);
    }

    const inner = raw.slice(openParen + 1, closeParen).trim();
    // Support both comma-separated and modern slash syntax: `r g b / a`
    let parts: string[] = [];
    if (inner.includes(",")) {
      parts = inner.split(",").map((s) => s.trim());
    } else if (inner.includes("/")) {
      const [rgbPart, aPart] = inner.split("/").map((s) => s.trim());
      const rgbTokens = rgbPart.split(/\s+/);
      parts = [...rgbTokens, aPart];
    } else {
      parts = inner.split(/\s+/);
    }

    if (parts.length !== 3 && parts.length !== 4) {
      throw new Error(`Invalid color: "${colorStr}"`);
    }

    const r = parseRgbComponent(parts[0]);
    const g = parseRgbComponent(parts[1]);
    const b = parseRgbComponent(parts[2]);
    const a = parts.length === 4 ? parseAlphaToken(parts[3]) : 1;

    return rgbToHsl(r, g, b, a);
  }

  // HSL / HSLA
  if (lower.startsWith("hsl(") || lower.startsWith("hsla(")) {
    const openParen = raw.indexOf("(");
    const closeParen = raw.lastIndexOf(")");
    if (openParen === -1 || closeParen === -1 || closeParen <= openParen) {
      throw new Error(`Invalid color: "${colorStr}"`);
    }

    const inner = raw.slice(openParen + 1, closeParen).trim();
    let parts: string[] = [];
    if (inner.includes(",")) {
      parts = inner.split(",").map((s) => s.trim());
    } else if (inner.includes("/")) {
      const [hslPart, aPart] = inner.split("/").map((s) => s.trim());
      const hslTokens = hslPart.split(/\s+/);
      parts = [...hslTokens, aPart];
    } else {
      parts = inner.split(/\s+/);
    }

    if (parts.length !== 3 && parts.length !== 4) {
      throw new Error(`Invalid color: "${colorStr}"`);
    }

    const h = parseHueToken(parts[0]);
    const s = parsePercentageToken(parts[1]);
    const l = parsePercentageToken(parts[2]);
    const a = parts.length === 4 ? parseAlphaToken(parts[3]) : 1;

    return {
      h: Math.round(h * 100) / 100,
      s: Math.round(s * 100) / 100,
      l: Math.round(l * 100) / 100,
      a: Math.round(a * 10000) / 10000,
    };
  }

  throw new Error(`Invalid color: "${colorStr}"`);
}

/**
 * Safely attempts to parse a string into HslColor. Returns null if invalid.
 */
export function tryParseColor(value: unknown): HslColor | null {
  if (typeof value !== "string") return null;
  try {
    return parseColor(value);
  } catch {
    return null;
  }
}

/**
 * Tests whether a value is a valid color string.
 */
export function isColorString(value: unknown): value is string {
  return tryParseColor(value) !== null;
}

/**
 * Formats alpha to clean string (e.g. 0.84, not 0.8400000000000001).
 */
function formatAlpha(a: number): string {
  const rounded = Math.round(a * 10000) / 10000;
  return rounded.toString();
}

/**
 * Formats an HslColor as `hsla(h, s%, l%, a)` or `hsl(h, s%, l%)`.
 */
export function formatHsl(color: HslColor): string {
  const h = Math.round(color.h);
  const s = Math.round(color.s);
  const l = Math.round(color.l);
  if (color.a < 1) {
    return `hsla(${h}, ${s}%, ${l}%, ${formatAlpha(color.a)})`;
  }
  return `hsl(${h}, ${s}%, ${l}%)`;
}

/**
 * Formats an HslColor or RgbColor as a canonical 6-digit hex string `#rrggbb` (lowercase).
 */
export function formatHex(color: HslColor | RgbColor): string {
  const rgb = "r" in color ? color : hslToRgb(color.h, color.s, color.l, color.a);
  const rHex = Math.max(0, Math.min(255, Math.round(rgb.r))).toString(16).padStart(2, "0");
  const gHex = Math.max(0, Math.min(255, Math.round(rgb.g))).toString(16).padStart(2, "0");
  const bHex = Math.max(0, Math.min(255, Math.round(rgb.b))).toString(16).padStart(2, "0");
  return `#${rHex}${gHex}${bHex}`.toLowerCase();
}

/**
 * Converts a color to a canonical output string.
 *
 * Uses lowercase `#rrggbb` for fully opaque colors (a === 1) and
 * `hsla(h, s%, l%, a)` for colors with transparency (a < 1).
 */
export function toCanonicalColor(color: HslColor | RgbColor): string {
  const a = color.a ?? 1;
  if (a < 1) {
    const hsl = "h" in color ? color : rgbToHsl(color.r, color.g, color.b, color.a);
    const h = Math.round(hsl.h);
    const s = Math.round(hsl.s);
    const l = Math.round(hsl.l);
    return `hsla(${h}, ${s}%, ${l}%, ${formatAlpha(a)})`;
  }
  return formatHex(color);
}

function toRgb(color: string | HslColor | RgbColor): RgbColor {
  if (typeof color === "string") {
    const parsed = parseColor(color);
    return hslToRgb(parsed.h, parsed.s, parsed.l, parsed.a);
  }
  if ("r" in color) {
    return color;
  }
  return hslToRgb(color.h, color.s, color.l, color.a);
}

/**
 * Computes WCAG 2.1 relative luminance for a color [0..1].
 *
 * Formula: https://www.w3.org/WAI/GL/wiki/Relative_luminance
 */
export function relativeLuminance(color: string | HslColor | RgbColor): number {
  const rgb = toRgb(color);

  function channelLuminance(channel255: number): number {
    const srgb = Math.max(0, Math.min(255, channel255)) / 255;
    return srgb <= 0.04045 ? srgb / 12.92 : Math.pow((srgb + 0.055) / 1.055, 2.4);
  }

  const rLin = channelLuminance(rgb.r);
  const gLin = channelLuminance(rgb.g);
  const bLin = channelLuminance(rgb.b);

  return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin;
}

/**
 * Computes WCAG 2.1 contrast ratio between two colors [1..21].
 */
export function contrastRatio(
  color1: string | HslColor | RgbColor,
  color2: string | HslColor | RgbColor
): number {
  const lum1 = relativeLuminance(color1);
  const lum2 = relativeLuminance(color2);

  const lighter = Math.max(lum1, lum2);
  const darker = Math.min(lum1, lum2);

  return (lighter + 0.05) / (darker + 0.05);
}
