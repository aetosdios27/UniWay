import { z } from "zod";
import { sql } from "@/lib/db";
import { PoiIconKeySchema } from "@/lib/poi-icons";
import { RoutingPointSchema } from "@/lib/schemas/db";

export const MapPoiSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  category: z.string().min(1),
  icon_key: PoiIconKeySchema.nullable().optional().transform(v => v ?? null),
  tags: z.array(z.string()).nullish().transform(v => v ?? []),
  routing_node_id: z.string().nullable().optional().transform(v => v ?? null),
  geom: RoutingPointSchema,
});
export type MapPoi = z.infer<typeof MapPoiSchema>;

export async function fetchMapPois(campusId: string, category?: string): Promise<MapPoi[]> {
  const rows = category !== undefined
    ? await sql`
        SELECT id, name, category, icon_key, COALESCE(tags, '{}') AS tags, routing_node_id,
          ST_AsGeoJSON(geom, 15)::json AS geom
        FROM campus_pois
        WHERE campus_id = ${campusId} AND category = ${category}
        ORDER BY name, id
      `
    : await sql`
        SELECT id, name, category, icon_key, COALESCE(tags, '{}') AS tags, routing_node_id,
          ST_AsGeoJSON(geom, 15)::json AS geom
        FROM campus_pois
        WHERE campus_id = ${campusId}
        ORDER BY name, id
      `;
  return z.array(MapPoiSchema).parse(rows);
}
