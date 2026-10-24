#!/usr/bin/env bun
/**
 * CLI script to generate the UniWay Dark map style from OpenFreeMap Liberty or a local file.
 *
 * Usage:
 *   bun scripts/build-dark-style.ts [--source <url-or-file>] [--out <path>]
 */

import fs from "node:fs";
import path from "node:path";
import { darkenStyle } from "../lib/map-style/dark-style";
import { parseStyleJson, resolveStyleOutput, resolveStyleSource } from "../lib/map-style/style-input";

interface CliArgs {
  source: string;
  out: string;
}

function parseArgs(args: string[]): CliArgs {
  let source = "https://tiles.openfreemap.org/styles/liberty";
  let out = "mobile/assets/map/uniway_dark_style.json";

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--source" || arg === "-s") {
      const val = args[++i];
      if (!val) {
        throw new Error("Missing value for --source argument.");
      }
      source = val;
    } else if (arg === "--out" || arg === "-o") {
      const val = args[++i];
      if (!val) {
        throw new Error("Missing value for --out argument.");
      }
      out = val;
    } else if (arg === "--help" || arg === "-h") {
      console.log(`
UniWay Dark Map Style Generator

Usage:
  bun scripts/build-dark-style.ts [options]

Options:
  --source, -s <url-or-path>  OpenFreeMap HTTPS URL or local file path
                              (default: https://tiles.openfreemap.org/styles/liberty)
  --out, -o <path>            Repository .json output path
                              (default: mobile/assets/map/uniway_dark_style.json)
  --help, -h                  Show this help message
`);
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: "${arg}". Use --help for usage.`);
    }
  }

  return { source, out };
}

async function loadSourceJson(source: string) {
  const location = resolveStyleSource(source);
  let rawText = "";

  if (location.kind === "url") {
    let response: Response;
    try {
      response = await fetch(location.value, {
        redirect: "error",
        headers: {
          "User-Agent": "UniWayDarkStyleGenerator/1.0 (+https://github.com/uniway)",
          Accept: "application/json",
        },
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      throw new Error(`Network failure fetching source style from "${source}": ${message}`);
    }

    if (!response.ok) {
      throw new Error(
        `Failed to fetch source style from "${source}": HTTP ${response.status} ${response.statusText}`
      );
    }

    rawText = await response.text();
  } else {
    const resolvedPath = path.resolve(process.cwd(), source);
    if (!fs.existsSync(resolvedPath)) {
      throw new Error(`Source style file does not exist: "${resolvedPath}"`);
    }
    try {
      rawText = fs.readFileSync(resolvedPath, "utf-8");
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      throw new Error(`Failed to read source style file "${resolvedPath}": ${message}`);
    }
  }

  try {
    return parseStyleJson(rawText);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    throw new Error(`Failed to validate style JSON from "${source}": ${message}`);
  }
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const outResolved = resolveStyleOutput(process.cwd(), args.out);

  console.log(`📥 Loading source map style from: ${args.source}`);
  const sourceStyle = await loadSourceJson(args.source);

  console.log(`🎨 Generating UniWay Dark style...`);
  const darkStyle = darkenStyle(sourceStyle);

  // Create the directory first so there is no check-then-write window, then
  // confirm its real path is still inside the repository (symlinks resolved).
  fs.mkdirSync(path.dirname(outResolved), { recursive: true });
  resolveStyleOutput(
    fs.realpathSync(process.cwd()),
    path.join(fs.realpathSync(path.dirname(outResolved)), path.basename(outResolved))
  );

  const formattedJson = JSON.stringify(darkStyle, null, 2) + "\n";
  // O_NOFOLLOW makes the open fail if the output itself is a symlink.
  const fd = fs.openSync(
    outResolved,
    fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_TRUNC | fs.constants.O_NOFOLLOW,
    0o644
  );
  try {
    fs.writeFileSync(fd, formattedJson, "utf-8");
  } finally {
    fs.closeSync(fd);
  }

  const layersCount = Array.isArray(darkStyle.layers) ? darkStyle.layers.length : 0;
  console.log(`✅ Dark style written to: ${path.relative(process.cwd(), outResolved)} (${layersCount} layers)`);
}

main().catch((err: unknown) => {
  const message = err instanceof Error ? err.message : String(err);
  console.error(`❌ Build error: ${message}`);
  process.exit(1);
});
