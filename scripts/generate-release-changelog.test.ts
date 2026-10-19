import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, describe, expect, it } from "vitest";
import { generateReleaseNotes, mergeChangelog } from "./generate-release-changelog";

const tempRoots: string[] = [];
afterAll(() => {
  for (const root of tempRoots) rmSync(root, { recursive: true, force: true });
});

function invalidDatasetDir(): string {
  const dir = join(mkdtempSync(join(tmpdir(), "uniway-release-")), "broken");
  tempRoots.push(dir);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "nodes.geojson"), "not json at all");
  return dir;
}

describe("generateReleaseNotes", () => {
  it("builds release notes from the shipped dataset metrics", () => {
    const { markdown, stats } = generateReleaseNotes("data/muj", "v1.2.3");
    expect(stats).toMatchObject({ totalNodes: 118, totalEdges: 153, totalDestinations: 7 });
    const lines = markdown.split("\n");
    expect(lines[0]).toBe("## [v1.2.3] - " + new Date().toISOString().slice(0, 10));
    expect(markdown).toContain("### Campus routing dataset metrics (data/muj)");
    expect(markdown).toContain("- Routing nodes: **118** (NID 1 – 118, expected 118)");
    expect(markdown).toContain("- NID continuity: fully sequential, no gaps");
    expect(markdown).toContain("- Dataset validation: passed (0 corrupted files");
  });

  it("refuses to generate notes for an invalid dataset", () => {
    expect(() => generateReleaseNotes(invalidDatasetDir(), "v9")).toThrow("Cannot generate release changelog for invalid dataset");
  });
});

describe("mergeChangelog", () => {
  const intro = "# Changelog\n\nAll notable changes to UniWay will be documented in this file.\n";

  it("prepends a new entry on top of existing ones", () => {
    const existing = `${intro}\n## [v0.2.0] - 2026-01-02\n\n- older\n`;
    const merged = mergeChangelog(existing, "## [v0.3.0] - 2026-03-03\n\n- newest\n", "v0.3.0");
    expect(merged.startsWith(intro)).toBe(true);
    expect(merged.indexOf("## [v0.3.0]")).toBeLessThan(merged.indexOf("## [v0.2.0]"));
    expect(merged).toContain("- older\n");
  });

  it("replaces a previous entry for the same version instead of stacking it", () => {
    const existing = `${intro}\n## [v0.1.0] - 2026-01-01\n\n- stale content\n\n## [v0.2.0] - 2026-01-02\n\n- keep me\n`;
    const merged = mergeChangelog(existing, "## [v0.1.0] - 2026-02-01\n\n- refreshed\n", "v0.1.0");
    expect(merged).not.toContain("- stale content");
    expect(merged).toContain("## [v0.2.0] - 2026-01-02\n\n- keep me");
    expect(merged).toContain("- refreshed\n");
  });

  it("adopts changelogs without the standard intro", () => {
    const merged = mergeChangelog("# My notes\n\n## [v0.1.0] - 2026-01-01\n- old\n", "## [v0.2.0] - 2026-01-02\n- new\n", "v0.2.0");
    expect(merged.startsWith(intro)).toBe(true);
    expect(merged).toContain("# My notes");
  });

  it("keeps Unreleased first and inserts the new version right after it", () => {
    const existing = `${intro}\n## [Unreleased]\n\n- wip\n\n## [v0.2.0] - 2026-01-02\n\n- older\n`;
    const merged = mergeChangelog(existing, "## [v0.3.0] - 2026-03-03\n\n- newest\n", "v0.3.0");
    expect(merged.indexOf("## [Unreleased]")).toBeLessThan(merged.indexOf("## [v0.3.0]"));
    expect(merged.indexOf("## [v0.3.0]")).toBeLessThan(merged.indexOf("## [v0.2.0]"));
    expect(merged).toContain("- wip\n\n## [v0.3.0]");
  });

  it("places the new version below a lone Unreleased block", () => {
    const merged = mergeChangelog(`${intro}\n## [Unreleased]\n\n- wip\n`, "## [v0.1.0] - 2026-01-01\n\n- first\n", "v0.1.0");
    expect(merged).toBe(`${intro}\n## [Unreleased]\n\n- wip\n\n## [v0.1.0] - 2026-01-01\n\n- first\n`);
  });

  it("stays idempotent for the same version when Unreleased is present", () => {
    const existing = `${intro}\n## [Unreleased]\n\n- wip\n\n## [v0.1.0] - 2026-01-01\n\n- stale content\n\n## [v0.0.9] - 2025-12-01\n\n- oldest\n`;
    const markdown = "## [v0.1.0] - 2026-02-01\n\n- refreshed\n";
    const once = mergeChangelog(existing, markdown, "v0.1.0");
    const twice = mergeChangelog(once, markdown, "v0.1.0");
    expect(twice).toBe(once);
    expect(once).not.toContain("- stale content");
    expect(once.split("## [v0.1.0]")).toHaveLength(2);
    expect(once.indexOf("## [Unreleased]")).toBeLessThan(once.indexOf("## [v0.1.0]"));
    expect(once.indexOf("## [v0.1.0]")).toBeLessThan(once.indexOf("## [v0.0.9]"));
  });

  it("leaves changelogs without an Unreleased block unchanged", () => {
    const merged = mergeChangelog(`${intro}\n## [v0.2.0] - 2026-01-02\n\n- older\n`, "## [v0.3.0] - 2026-03-03\n\n- newest\n", "v0.3.0");
    expect(merged).toBe(`${intro}\n## [v0.3.0] - 2026-03-03\n\n- newest\n\n## [v0.2.0] - 2026-01-02\n\n- older\n`);
  });
});
