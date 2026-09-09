import { sql } from "@/lib/db";
import {
  CreateObstructionReportInput,
  ObstructionReportSchema,
  type ObstructionReport,
} from "@/lib/schemas/db";

export async function createObstructionReport(
  input: CreateObstructionReportInput
): Promise<ObstructionReport> {
  if (input.lng !== undefined && input.lat !== undefined) {
    const { lng, lat } = input;
    const result = await sql`
      INSERT INTO obstruction_reports (room_id, edge_id, description, geom)
      VALUES (
        ${input.roomId ?? null},
        ${input.edgeId ?? null},
        ${input.description},
        ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
      )
      RETURNING id, room_id, edge_id, description, status, reported_at, resolved_at
    `;

    return ObstructionReportSchema.parse(result[0]);
  }

  const result = await sql`
    INSERT INTO obstruction_reports (room_id, edge_id, description)
    VALUES (
      ${input.roomId ?? null},
      ${input.edgeId ?? null},
      ${input.description}
    )
    RETURNING id, room_id, edge_id, description, status, reported_at, resolved_at
  `;

  return ObstructionReportSchema.parse(result[0]);
}

export async function fetchCampusReports(
  campusId: string,
  status: string = "open",
  offset = 0,
  limit = 20
): Promise<{ reports: ObstructionReport[]; total: number }> {
  const [countRow] = await sql`
    SELECT COUNT(*) AS total
    FROM obstruction_reports r
    LEFT JOIN rooms ON r.room_id = rooms.id
    LEFT JOIN buildings ON rooms.building_id = buildings.id
    LEFT JOIN routing_edges e ON r.edge_id = e.id
    LEFT JOIN rooms edge_room ON e.source_node_id = edge_room.id
    LEFT JOIN buildings edge_building ON edge_room.building_id = edge_building.id
    WHERE (buildings.campus_id = ${campusId} OR edge_building.campus_id = ${campusId})
      AND r.status = ${status}
  `;
  const total = Number(countRow.total);

  const result = await sql`
    SELECT r.id, r.room_id, r.edge_id, r.description, r.status, r.reported_at, r.resolved_at
    FROM obstruction_reports r
    LEFT JOIN rooms ON r.room_id = rooms.id
    LEFT JOIN buildings ON rooms.building_id = buildings.id
    LEFT JOIN routing_edges e ON r.edge_id = e.id
    LEFT JOIN rooms edge_room ON e.source_node_id = edge_room.id
    LEFT JOIN buildings edge_building ON edge_room.building_id = edge_building.id
    WHERE (buildings.campus_id = ${campusId} OR edge_building.campus_id = ${campusId})
      AND r.status = ${status}
    ORDER BY r.reported_at DESC, r.id
    LIMIT ${limit}
    OFFSET ${offset}
  `;

  const reports = result.map((row: Record<string, unknown>) => ObstructionReportSchema.parse(row));
  return { reports, total };
}
