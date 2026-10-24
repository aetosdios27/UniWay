import { validateDatasetDirectory } from "../lib/spatial/dataset-validation";

const directory = process.argv[2] ?? "data/muj";

console.log(`🔍 Validating campus dataset at: ${directory}`);
const report = validateDatasetDirectory(directory);

console.log("\n📊 Dataset Validation Summary:");
console.log(`  • Valid: ${report.valid ? "✅ YES" : "❌ NO"}`);
console.log(`  • Routing Nodes: ${report.stats.totalNodes}`);
console.log(`  • NID Sequential Range: ${report.stats.minNid} to ${report.stats.maxNid} (Expected: ${report.stats.maxNid - report.stats.minNid + 1})`);
console.log(`  • Missing / Skipped NIDs: ${report.stats.missingNids.length === 0 ? "0 (Fully Sequential)" : `❌ ${report.stats.missingNids.join(", ")}`}`);
console.log(`  • Routing Edges: ${report.stats.totalEdges}`);
console.log(`  • Destinations: ${report.stats.totalDestinations}`);
console.log(`  • Campus POIs: ${report.stats.totalPois}`);
console.log(`  • Graph Components: ${report.stats.componentsCount}`);

if (report.corruptedFiles.length > 0) {
  console.log("\n❌ Corrupted Files Detected:");
  for (const f of report.corruptedFiles) {
    console.log(`  - ${f.file}: ${f.error}`);
  }
}

if (report.errors.length > 0) {
  console.log("\n❌ Validation Errors:");
  for (const err of report.errors) {
    console.log(`  - ${err}`);
  }
}

if (report.warnings.length > 0) {
  console.log("\n⚠️  Warnings:");
  for (const warn of report.warnings) {
    console.log(`  - ${warn}`);
  }
}

process.exitCode = report.valid ? 0 : 1;
