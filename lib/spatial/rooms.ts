import { sql } from "@/lib/db";
import { RoomSchema } from "@/lib/schemas/db";
import { z } from "zod";

const RoomListItemSchema = z.object({
  id: z.string().uuid(),
  building_id: z.string().uuid(),
  floor: z.string(),
  name: z.string(),
});
type RoomListItem = z.infer<typeof RoomListItemSchema>;

export async function fetchRooms(
  campusId: string,
  buildingId?: string,
  offset = 0,
  limit = 20
): Promise<{ rooms: RoomListItem[]; total: number }> {
  const buildingFilter = buildingId ? sql`AND r.building_id = ${buildingId}` : sql``;

  const [[countRow], rows] = await Promise.all([
    sql`
      SELECT COUNT(*) AS total
      FROM rooms r
      JOIN buildings b ON r.building_id = b.id
      WHERE b.campus_id = ${campusId} ${buildingFilter}
    `,
    sql`
      SELECT r.id, r.building_id, r.floor, r.name
      FROM rooms r
      JOIN buildings b ON r.building_id = b.id
      WHERE b.campus_id = ${campusId} ${buildingFilter}
      ORDER BY r.floor ASC, r.name ASC
      LIMIT ${limit}
      OFFSET ${offset}
    `,
  ]);
  const total = Number(countRow?.total ?? 0);

  const rooms = rows.map((row: Record<string, unknown>) => RoomListItemSchema.parse(row));
  return { rooms, total };
}

export async function getCampusIdForRoom(roomId: string): Promise<string | null> {
  const result = await sql`
    SELECT b.campus_id
    FROM rooms r
    JOIN buildings b ON r.building_id = b.id
    WHERE r.id = ${roomId}
  `;

  return result[0]?.campus_id ?? null;
}

const RoomDetailSchema = RoomSchema.extend({
  building_name: z.string(),
  campus_id: z.string().uuid(),
  campus_name: z.string(),
});
export type RoomDetail = z.infer<typeof RoomDetailSchema>;

export async function fetchRoomById(roomId: string): Promise<RoomDetail | null> {
  const result = await sql`
    SELECT
      r.id,
      r.building_id,
      r.floor,
      r.name,
      ST_AsGeoJSON(r.geom)::json AS geom,
      ST_AsGeoJSON(r.centroid)::json AS centroid,
      b.name AS building_name,
      c.id AS campus_id,
      c.name AS campus_name
    FROM rooms r
    JOIN buildings b ON r.building_id = b.id
    JOIN campuses c ON b.campus_id = c.id
    WHERE r.id = ${roomId}
  `;

  if (result.length === 0) return null;
  return RoomDetailSchema.parse(result[0]);
}

export async function fetchRoomCentroidsForCampus(
  campusId: string
): Promise<Map<string, [number, number]>> {
  const result = await sql`
    SELECT r.id, ST_AsGeoJSON(r.centroid)::json AS centroid
    FROM rooms r
    JOIN buildings b ON r.building_id = b.id
    WHERE b.campus_id = ${campusId}
  `;

  const map = new Map<string, [number, number]>();
  for (const row of result) {
    if (row.centroid && row.centroid.coordinates) {
      map.set(row.id, row.centroid.coordinates as [number, number]);
    }
  }

  return map;
}
