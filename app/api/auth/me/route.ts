import { apiError, successResponse, unauthorized } from "@/lib/api-response";
import { getAuthenticatedUser } from "@/lib/auth";
import { withRateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const rateLimitResponse = withRateLimit(request, { maxRequests: 30, windowMs: 60_000 });
  if (rateLimitResponse) return rateLimitResponse;

  try {
    const user = await getAuthenticatedUser(request);
    if (!user) {
      return unauthorized("Unauthorized", undefined, request);
    }

    return successResponse({ user });
  } catch (error) {
    return apiError(error, "Failed to get current user", request);
  }
}
