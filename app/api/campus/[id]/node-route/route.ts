import { z } from "zod";
import { AccessibleBool, CoordString, apiError, badRequest, formatZodError, notFound, successResponse } from "@/lib/api-response";
import { withRateLimit } from "@/lib/rate-limit";
import { RoutingNodeIdSchema } from "@/lib/schemas/db";
import { isPointInCampus } from "@/lib/spatial/campus";
import { getNearestRoutingNode } from "@/lib/spatial/nodes";
import { findNodeRoute } from "@/lib/routing/nodes";

export const dynamic = "force-dynamic";
const QuerySchema = z.object({
  campusId: z.string().uuid(),
  fromLng: CoordString(-180, 180),
  fromLat: CoordString(-90, 90),
  toNodeId: RoutingNodeIdSchema,
  floor: z.string().trim().min(1).max(20).default("0"),
  accessible: AccessibleBool,
});

async function calculateRoute(input: z.infer<typeof QuerySchema>, request: Request) {
  const { campusId, fromLng, fromLat, toNodeId, floor, accessible = false } = input;
  if (!await isPointInCampus(fromLng, fromLat, campusId)) {
    return notFound("Location is outside campus bounds", undefined, request);
  }
  const start = await getNearestRoutingNode(campusId, fromLng, fromLat, floor, accessible);
  if (!start) return notFound("No routing node within 50 metres", undefined, request);
  const route = await findNodeRoute(campusId, start.node_id, toNodeId, accessible);
  if (!route) return notFound("Could not find a valid route to the destination", undefined, request);
  const response = successResponse(route);
  response.headers.set("Cache-Control", "no-store");
  return response;
}

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const limited = withRateLimit(request, { maxRequests: 60, windowMs: 60_000 });
  if (limited) return limited;
  try {
    const { id: campusId } = await params;
    const parsed = QuerySchema.safeParse({ ...Object.fromEntries(new URL(request.url).searchParams), campusId });
    if (!parsed.success) return badRequest("Validation failed", formatZodError(parsed.error), undefined, request);
    return await calculateRoute(parsed.data, request);
  } catch (error) {
    return apiError(error, "Failed to calculate node route", request);
  }
}
