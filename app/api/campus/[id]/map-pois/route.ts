import { z } from "zod";
import { apiError, badRequest, successResponse } from "@/lib/api-response";
import { withRateLimit } from "@/lib/rate-limit";
import { fetchMapPois } from "@/lib/spatial/map-pois";

export const dynamic = "force-dynamic";

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const limited = withRateLimit(request);
  if (limited) return limited;
  try {
    const { id } = await params;
    if (!z.string().uuid().safeParse(id).success) {
      return badRequest("Invalid campus ID", undefined, undefined, request);
    }
    const { searchParams } = new URL(request.url);
    const category = searchParams.get("category")?.trim() || undefined;
    if (category !== undefined && category.length > 50) {
      return badRequest("category must be at most 50 characters", undefined, undefined, request);
    }
    return successResponse(await fetchMapPois(id, category), 200, 300);
  } catch (error) {
    return apiError(error, "Failed to fetch map POIs", request);
  }
}
