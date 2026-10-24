import path from "node:path";
import { z } from "zod";

const jsonObject = z.record(z.string(), z.json());
const sourceSchema = z.object({
  type: z.enum(["vector", "raster", "raster-dem", "geojson", "image", "video"]),
  url: z.string().optional(),
  tiles: z.array(z.string()).optional(),
}).passthrough();
const layerSchema = z.object({
  id: z.string().min(1),
  type: z.enum([
    "background", "fill", "line", "symbol", "raster", "circle",
    "fill-extrusion", "heatmap", "hillshade", "color-relief", "sky", "model", "clip",
  ]),
  paint: jsonObject.optional(),
  layout: jsonObject.optional(),
}).passthrough();
const styleSchema = z.object({
  version: z.literal(8),
  name: z.string().optional(),
  metadata: jsonObject.optional(),
  sources: z.record(z.string(), sourceSchema),
  layers: z.array(layerSchema),
  sprite: z.string().optional(),
  glyphs: z.string().optional(),
}).passthrough();

// Parse every value as JSON, then validate the fields the transformer consumes.
// Using a record preserves source key order, including passthrough extensions,
// so re-serialization does not cause unrelated changes to the generated asset.
const orderedStyleSchema = jsonObject.superRefine((value, context) => {
  const result = styleSchema.safeParse(value);
  if (!result.success) {
    for (const issue of result.error.issues) {
      context.addIssue({ code: "custom", path: issue.path, message: issue.message });
    }
  }
});

export function parseStyleJson(text: string) {
  const value: unknown = JSON.parse(text);
  return orderedStyleSchema.parse(value);
}

/** Output paths are relative to the invocation's repository root (cwd). */
export function resolveStyleOutput(root: string, output: string): string {
  const resolved = path.resolve(root, output);
  const relative = path.relative(path.resolve(root), resolved);
  if (relative === ".." || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
    throw new Error("Output must stay inside the repository.");
  }
  if (path.extname(resolved) !== ".json") {
    throw new Error("Output must be a .json file.");
  }
  return resolved;
}

/** Explicit local paths are allowed; URL sources must use this exact HTTPS origin. */
export function resolveStyleSource(source: string): { kind: "url" | "file"; value: string } {
  if (!/^[a-z][a-z\d+.-]*:/i.test(source) && !source.startsWith("//")) {
    return { kind: "file", value: source };
  }
  const url = new URL(source);
  if (url.origin !== "https://tiles.openfreemap.org" || url.username || url.password) {
    throw new Error("Source URLs must use https://tiles.openfreemap.org/.");
  }
  return { kind: "url", value: url.href };
}
