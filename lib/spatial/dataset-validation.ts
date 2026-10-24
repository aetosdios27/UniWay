import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { QgisDataset, QgisDatasetSchema, validateQgisDataset } from "@/lib/spatial/qgis";

export interface FileCorruptionResult {
  file: string;
  corrupted: boolean;
  error?: string;
  data?: unknown;
}

export interface DatasetValidationReport {
  valid: boolean;
  directory: string;
  files: {
    nodesFile: string;
    edgesFile: string;
    destinationsFile: string;
    poisFile?: string;
  };
  corruptedFiles: FileCorruptionResult[];
  errors: string[];
  warnings: string[];
  stats: {
    totalNodes: number;
    minNid: number;
    maxNid: number;
    missingNids: number[];
    totalEdges: number;
    totalDestinations: number;
    totalPois: number;
    componentsCount: number;
  };
}

/**
 * Safely parses a JSON file and returns the parsed object or records corruption error.
 */
export function safeReadJson(filePath: string): { data?: unknown; error?: string } {
  try {
    const raw = readFileSync(filePath, "utf8");
    const data = JSON.parse(raw);
    return { data };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { error: `Corrupted JSON in '${filePath}': ${message}` };
  }
}

/**
 * Validates that all .json and .geojson files in a directory are uncorrupted valid JSON.
 */
export function checkDirectoryJsonIntegrity(dirPath: string): FileCorruptionResult[] {
  if (!existsSync(dirPath)) {
    return [{ file: dirPath, corrupted: true, error: `Directory does not exist: ${dirPath}` }];
  }

  const results: FileCorruptionResult[] = [];
  const entries = readdirSync(dirPath);

  for (const entry of entries) {
    if (entry.startsWith(".")) continue;
    const fullPath = join(dirPath, entry);
    const stat = statSync(fullPath);

    if (stat.isDirectory()) {
      results.push(...checkDirectoryJsonIntegrity(fullPath));
    } else if (entry.endsWith(".json") || entry.endsWith(".geojson")) {
      const { data, error } = safeReadJson(fullPath);
      results.push({
        file: fullPath,
        corrupted: Boolean(error),
        error,
        data,
      });
    }
  }

  return results;
}

/**
 * Validates an entire QGIS campus dataset directory (e.g. data/muj).
 * Ensures JSON files are not corrupted, schemas match, NIDs are sequential without gaps,
 * and node names match the canonical OUT_<loc>_<floor_id>_<nid> convention.
 */
export function validateDatasetDirectory(directory: string): DatasetValidationReport {
  const nodesFile = join(directory, "nodes.geojson");
  const edgesFile = join(directory, "edges.geojson");
  const destinationsFile = join(directory, "destinations.geojson");
  const poisFile = join(directory, "pois.geojson");
  const hasPois = existsSync(poisFile);

  const integrity = checkDirectoryJsonIntegrity(directory);
  const corruptedFiles = integrity.filter(f => f.corrupted);
  const dataOf = (file: string) => integrity.find(f => f.file === file)?.data;
  const errors: string[] = [];
  const warnings: string[] = [];

  if (corruptedFiles.length > 0) {
    for (const f of corruptedFiles) {
      errors.push(f.error ?? `File '${f.file}' is corrupted`);
    }
  }

  for (const required of [nodesFile, edgesFile, destinationsFile]) {
    if (!existsSync(required)) {
      errors.push(`Required dataset file missing: ${required}`);
    }
  }

  const emptyStats = {
    totalNodes: 0,
    minNid: 0,
    maxNid: 0,
    missingNids: [],
    totalEdges: 0,
    totalDestinations: 0,
    totalPois: 0,
    componentsCount: 0,
  };

  if (errors.length > 0) {
    return {
      valid: false,
      directory,
      files: {
        nodesFile,
        edgesFile,
        destinationsFile,
        ...(hasPois ? { poisFile } : {}),
      },
      corruptedFiles,
      errors,
      warnings,
      stats: emptyStats,
    };
  }

  const parsed = QgisDatasetSchema.safeParse({
    nodes: dataOf(nodesFile),
    edges: dataOf(edgesFile),
    destinations: dataOf(destinationsFile),
    ...(hasPois ? { pois: dataOf(poisFile) } : {}),
  });

  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      errors.push(`Schema error at ${issue.path.join(".")}: ${issue.message}`);
    }
    return {
      valid: false,
      directory,
      files: {
        nodesFile,
        edgesFile,
        destinationsFile,
        ...(hasPois ? { poisFile } : {}),
      },
      corruptedFiles,
      errors,
      warnings,
      stats: emptyStats,
    };
  }

  const dataset: QgisDataset = parsed.data;
  const validation = validateQgisDataset(dataset);

  errors.push(...validation.errors);
  warnings.push(...validation.warnings);

  return {
    valid: errors.length === 0,
    directory,
    files: {
      nodesFile,
      edgesFile,
      destinationsFile,
      ...(hasPois ? { poisFile } : {}),
    },
    corruptedFiles,
    errors,
    warnings,
    stats: {
      ...validation.stats,
      componentsCount: validation.components.length,
    },
  };
}
