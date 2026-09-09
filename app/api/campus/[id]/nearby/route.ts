import { z } from "zod";
import { withRateLimit } from "@/lib/rate-limit";
import { apiError, badRequest, notFound, parsePagination, paginatedResponse, CoordString, formatZodError } from "@/lib/api-response";
import { isPointInCampus } from "@/lib/spatial/campus";
import { findPoisWithinRadius, findRoomsWithinRadius } from "@/lib/spatial/proximity";

export const dynamic = "force-dynamic";

const NearbyQuerySchema = z.object({
  lat: CoordString(-90, 90),
  lng: CoordString(-180, 180),
  radius: z.coerce.number().positive().max(1000).default(50),
  type: z.enum(["pois", "rooms"]).default("pois"),
  floor: z.string().max(20).optional(),
  category: z.string().max(50).optional(),
});

async function nearbyResponse(campusId: string, query: z.infer<typeof NearbyQuerySchema>, searchParams: URLSearchParams) {
  const { lat, lng, radius, type, floor, category } = query;
  const pagination = parsePagination(searchParams, 20, 100);
  const { offset, limit } = pagination;
  // ponytail: slice campus-sized results in memory; move pagination into SQL if result sets grow.
  if (type === "rooms") {
    const rooms = await findRoomsWithinRadius(lng, lat, campusId, radius, floor);
    return paginatedResponse(rooms.slice(offset, offset + limit), rooms.length, pagination);
  }
  const pois = await findPoisWithinRadius(lng, lat, campusId, radius, category);
  return paginatedResponse(pois.slice(offset, offset + limit), pois.length, pagination);
}

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const rateLimitResponse = withRateLimit(request);
  if (rateLimitResponse) return rateLimitResponse;

  try {
    const { id: campusId } = await params;
    const { searchParams } = new URL(request.url);

    const parsed = NearbyQuerySchema.safeParse(Object.fromEntries(searchParams));

    if (!parsed.success) {
      return badRequest("Validation failed", formatZodError(parsed.error), undefined, request);
    }

    const inside = await isPointInCampus(parsed.data.lng, parsed.data.lat, campusId);
    if (!inside) {
      return notFound("Location is outside campus bounds", undefined, request);
    }

    return await nearbyResponse(campusId, parsed.data, searchParams);
  } catch (error) {
    return apiError(error, "Failed to fetch nearby places", request);
  }
}
