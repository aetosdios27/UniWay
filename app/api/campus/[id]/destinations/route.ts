import { z } from "zod";
import { apiError, badRequest, successResponse } from "@/lib/api-response";
import { withRateLimit } from "@/lib/rate-limit";
import { fetchRoutingDestinations } from "@/lib/spatial/nodes";

export const dynamic = "force-dynamic";

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const limited = withRateLimit(request);
  if (limited) return limited;
  try {
    const { id } = await params;
    if (!z.string().uuid().safeParse(id).success) return badRequest("Invalid campus ID", undefined, undefined, request);
    // Destinations only change on QGIS import (an admin operation), same cacheability as
    // buildings/rooms/pois below — this was the one GET route missing the header they all share.
    return successResponse(await fetchRoutingDestinations(id), 200, 300);
  } catch (error) {
    return apiError(error, "Failed to fetch destinations", request);
  }
}
