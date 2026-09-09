import { sql } from "@/lib/db";
import { POISearchResultSchema, POISuggestResultSchema, type POISearchResult, type POISuggestResult } from "@/lib/schemas/db";

const DEFAULT_SEARCH_LIMIT = 20;
const MAX_SEARCH_LIMIT = 50;

export async function searchPois(
  campusId: string,
  query: string,
  limit: number = DEFAULT_SEARCH_LIMIT,
  offset = 0,
  category?: string
): Promise<{ results: POISearchResult[]; total: number }> {
  const trimmedQuery = query.trim();
  if (trimmedQuery.length === 0) {
    return { results: [], total: 0 };
  }

  const boundedLimit = Math.min(Math.max(limit, 1), MAX_SEARCH_LIMIT);

  if (category) {
    return searchPoisWithCategory(campusId, trimmedQuery, boundedLimit, offset, category);
  }

  const [[countRow], result] = await Promise.all([
    sql`
      SELECT COUNT(*) AS total
      FROM pois p
      JOIN rooms r ON p.room_id = r.id
      JOIN buildings b ON r.building_id = b.id
      WHERE b.campus_id = ${campusId}
        AND (
          p.search_vector @@ plainto_tsquery('english', ${trimmedQuery})
          OR p.name % ${trimmedQuery}
          OR r.name ILIKE ${"%" + trimmedQuery + "%"}
        )
    `,
    sql`
      SELECT
        p.id,
        p.room_id,
        p.name,
        p.category,
        p.tags,
        ts_rank(p.search_vector, plainto_tsquery('english', ${trimmedQuery})) AS rank,
        r.floor,
        b.id AS building_id,
        b.name AS building_name
      FROM pois p
      JOIN rooms r ON p.room_id = r.id
      JOIN buildings b ON r.building_id = b.id
      WHERE b.campus_id = ${campusId}
        AND (
          p.search_vector @@ plainto_tsquery('english', ${trimmedQuery})
          OR p.name % ${trimmedQuery}
          OR r.name ILIKE ${"%" + trimmedQuery + "%"}
        )
      ORDER BY rank DESC, p.name ASC
      LIMIT ${boundedLimit}
      OFFSET ${offset}
    `,
  ]);
  const total = Number(countRow?.total ?? 0);

  const results = result.map((row: Record<string, unknown>) => POISearchResultSchema.parse(row));
  return { results, total };
}

async function searchPoisWithCategory(
  campusId: string,
  trimmedQuery: string,
  limit: number,
  offset: number,
  category: string
): Promise<{ results: POISearchResult[]; total: number }> {
  const [[countRow], result] = await Promise.all([
    sql`
      SELECT COUNT(*) AS total
      FROM pois p
      JOIN rooms r ON p.room_id = r.id
      JOIN buildings b ON r.building_id = b.id
      WHERE b.campus_id = ${campusId}
        AND (
          p.search_vector @@ plainto_tsquery('english', ${trimmedQuery})
          OR p.name % ${trimmedQuery}
          OR r.name ILIKE ${"%" + trimmedQuery + "%"}
        )
        AND p.category = ${category}
    `,
    sql`
      SELECT
        p.id,
        p.room_id,
        p.name,
        p.category,
        p.tags,
        ts_rank(p.search_vector, plainto_tsquery('english', ${trimmedQuery})) AS rank,
        r.floor,
        b.id AS building_id,
        b.name AS building_name
      FROM pois p
      JOIN rooms r ON p.room_id = r.id
      JOIN buildings b ON r.building_id = b.id
      WHERE b.campus_id = ${campusId}
        AND (
          p.search_vector @@ plainto_tsquery('english', ${trimmedQuery})
          OR p.name % ${trimmedQuery}
          OR r.name ILIKE ${"%" + trimmedQuery + "%"}
        )
        AND p.category = ${category}
      ORDER BY rank DESC, p.name ASC
      LIMIT ${limit}
      OFFSET ${offset}
    `,
  ]);
  const total = Number(countRow?.total ?? 0);

  return {
    results: result.map((row: Record<string, unknown>) => POISearchResultSchema.parse(row)),
    total,
  };
}

export async function suggestPois(
  campusId: string,
  query: string
): Promise<POISuggestResult[]> {
  const trimmedQuery = query.trim();
  if (trimmedQuery.length === 0) {
    return [];
  }

  const result = await sql`
    SELECT p.id, p.name, p.category
    FROM pois p
    JOIN rooms r ON p.room_id = r.id
    JOIN buildings b ON r.building_id = b.id
    WHERE b.campus_id = ${campusId}
      AND (
        p.name ILIKE ${trimmedQuery + "%"}
        OR p.name % ${trimmedQuery}
      )
    ORDER BY
      CASE WHEN p.name ILIKE ${trimmedQuery + "%"} THEN 0 ELSE 1 END,
      similarity(p.name, ${trimmedQuery}) DESC
    LIMIT 5
  `;

  return result.map((row: Record<string, unknown>) => POISuggestResultSchema.parse(row));
}
