import { sql } from "@/lib/db";
import { POISchema, RoomSchema, type POI, type Room } from "@/lib/schemas/db";
import { z } from "zod";
import { validateCoordinates } from "@/lib/spatial/coords";

export async function findRoomsWithinRadius(
  lng: number,
  lat: number,
  campusId: string,
  maxRadiusMeters: number = 50,
  floor?: string
): Promise<Room[]> {
  validateCoordinates(lng, lat, maxRadiusMeters);

  const result = floor
    ? await sql`
        SELECT
          r.id,
          r.building_id,
          r.floor,
          r.name,
          ST_AsGeoJSON(r.geom)::json AS geom,
          ST_AsGeoJSON(r.centroid)::json AS centroid
        FROM rooms r
        JOIN buildings b ON r.building_id = b.id
        WHERE b.campus_id = ${campusId}
          AND r.floor = ${floor}
          AND ST_DWithin(
            r.centroid::geography,
            ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography,
            ${maxRadiusMeters}
          )
        ORDER BY r.centroid <-> ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326), r.id
      `
    : await sql`
        SELECT
          r.id,
          r.building_id,
          r.floor,
          r.name,
          ST_AsGeoJSON(r.geom)::json AS geom,
          ST_AsGeoJSON(r.centroid)::json AS centroid
        FROM rooms r
        JOIN buildings b ON r.building_id = b.id
        WHERE b.campus_id = ${campusId}
          AND ST_DWithin(
            r.centroid::geography,
            ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography,
            ${maxRadiusMeters}
          )
        ORDER BY r.centroid <-> ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326), r.id
      `;

  return z.array(RoomSchema).parse(result);
}

export async function findPoisWithinRadius(
  lng: number,
  lat: number,
  campusId: string,
  maxRadiusMeters: number = 50,
  category?: string
): Promise<POI[]> {
  validateCoordinates(lng, lat, maxRadiusMeters);

  const result = category
    ? await sql`
        SELECT p.*
        FROM pois p
        JOIN rooms r ON p.room_id = r.id
        JOIN buildings b ON r.building_id = b.id
        WHERE b.campus_id = ${campusId}
          AND p.category = ${category}
          AND ST_DWithin(
            r.centroid::geography,
            ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography,
            ${maxRadiusMeters}
          )
        ORDER BY r.centroid <-> ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326), p.id
      `
    : await sql`
        SELECT p.*
        FROM pois p
        JOIN rooms r ON p.room_id = r.id
        JOIN buildings b ON r.building_id = b.id
        WHERE b.campus_id = ${campusId}
          AND ST_DWithin(
            r.centroid::geography,
            ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography,
            ${maxRadiusMeters}
          )
        ORDER BY r.centroid <-> ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326), p.id
      `;

  return z.array(POISchema).parse(result);
}
