import { readFileSync, writeFileSync } from "node:fs";
import { validateDatasetDirectory } from "../lib/spatial/dataset-validation";

const CHANGELOG_PATH = "CHANGELOG.md";
const CHANGELOG_INTRO =
  "# Changelog\n\nAll notable changes to UniWay will be documented in this file.\n";

function parseArgs() {
  const args = process.argv.slice(2);
  let version = "";
  let directory = "data/muj";
  let writeChangelog = false;
  let printOutput = false;
  let outputFile = "";

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--version" && args[i + 1]) {
      version = args[++i];
    } else if (args[i] === "--dir" && args[i + 1]) {
      directory = args[++i];
    } else if (args[i] === "--write") {
      writeChangelog = true;
    } else if (args[i] === "--print") {
      printOutput = true;
    } else if (args[i] === "--output" && args[i + 1]) {
      outputFile = args[++i];
    }
  }

  if (!version) {
    try {
      const pkg = JSON.parse(readFileSync("package.json", "utf8"));
      version = pkg.version ? `v${pkg.version}` : `v${new Date().toISOString().slice(0, 10)}`;
    } catch {
      version = `v${new Date().toISOString().slice(0, 10)}`;
    }
  }

  if (!version.startsWith("v")) {
    version = `v${version}`;
  }

  return { version, directory, writeChangelog, printOutput, outputFile };
}

/**
 * Builds the dataset-metrics section for a release entry. The dataset must
 * already be valid: release notes are only ever generated from a passing
 * validation, so integrity failures stop here rather than being reported
 * as a bullet item.
 */
export function generateReleaseNotes(directory = "data/muj", version = "v0.1.0") {
  const report = validateDatasetDirectory(directory);

  if (!report.valid) {
    throw new Error(`Cannot generate release changelog for invalid dataset:\n${report.errors.join("\n")}`);
  }

  const dateStr = new Date().toISOString().slice(0, 10);
  const { stats } = report;

  const markdown = [
    `## [${version}] - ${dateStr}`,
    "",
    `### Campus routing dataset metrics (${directory})`,
    `- Routing nodes: **${stats.totalNodes}** (NID ${stats.minNid} – ${stats.maxNid}, expected ${stats.maxNid - stats.minNid + 1})`,
    `- NID continuity: ${stats.missingNids.length === 0 ? "fully sequential, no gaps" : `gaps at ${stats.missingNids.join(", ")}`}`,
    `- Routing edges: **${stats.totalEdges}**`,
    `- Destinations: **${stats.totalDestinations}**`,
    `- Graph components: **${stats.componentsCount}**`,
    `- Dataset validation: passed (${report.corruptedFiles.length} corrupted files, canonical \`OUT_<loc>_<floor>_<nid>\` naming)`,
    "",
  ].join("\n");

  return { markdown, stats };
}

/**
 * Pure changelog merge: adds a version entry above older entries (below any
 * `## [Unreleased]` block) and replaces any earlier entry for the same version,
 * so re-running a release is idempotent.
 */
export function mergeChangelog(existing: string, markdown: string, version: string): string {
  const body = existing.startsWith(CHANGELOG_INTRO) ? existing.slice(CHANGELOG_INTRO.length) : existing;
  const blocks = body
    .split(/\n(?=## \[)/)
    .map(block => block.trim())
    .filter(block => block.length > 0 && !block.startsWith(`## [${version}]`));

  const insertAt = blocks.findIndex(block => block.startsWith("## [Unreleased]")) + 1;
  const ordered = [...blocks.slice(0, insertAt), markdown.trimEnd(), ...blocks.slice(insertAt)];
  return `${CHANGELOG_INTRO}\n${ordered.join("\n\n")}\n`;
}

export function upsertChangelog(markdown: string, version: string): void {
  let existing: string;
  try {
    existing = readFileSync(CHANGELOG_PATH, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    writeFileSync(CHANGELOG_PATH, `${CHANGELOG_INTRO}\n${markdown}`, "utf8");
    return;
  }
  writeFileSync(CHANGELOG_PATH, mergeChangelog(existing, markdown, version), "utf8");
}

function main() {
  const { version, directory, writeChangelog, printOutput, outputFile } = parseArgs();

  const { markdown } = generateReleaseNotes(directory, version);

  if (printOutput || (!writeChangelog && !outputFile)) {
    console.log(markdown);
  }

  if (outputFile) {
    writeFileSync(outputFile, markdown, "utf8");
    console.log(`Release notes written to ${outputFile}`);
  }

  if (writeChangelog) {
    upsertChangelog(markdown, version);
    console.log(`${CHANGELOG_PATH} updated with release ${version}`);
  }
}

if (process.argv[1]?.endsWith("generate-release-changelog.ts")) {
  main();
}
