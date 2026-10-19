import { apiError, badRequest, conflict, formatZodError, isUniqueViolation, successResponse, validateBodySize } from "@/lib/api-response";
import { hashPassword, signJwt } from "@/lib/auth";
import { sql } from "@/lib/db";
import { withRateLimit } from "@/lib/rate-limit";
import { RegisterRequestSchema, UserPublicSchema } from "@/lib/schemas/auth";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const rateLimitResponse = withRateLimit(request, { maxRequests: 10, windowMs: 60_000 });
  if (rateLimitResponse) return rateLimitResponse;

  const sizeCheck = await validateBodySize(request, 10_240);
  if (!sizeCheck.ok) return sizeCheck.response;

  try {
    const rawBody = JSON.parse(sizeCheck.body);
    const parsed = RegisterRequestSchema.safeParse(rawBody);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodError(parsed.error), undefined, request);
    }

    const { email, password, name } = parsed.data;

    const existing = await sql`
      SELECT id FROM users WHERE lower(email) = ${email} LIMIT 1
    `;
    if (existing.length > 0) {
      return conflict("An account with this email already exists", undefined, request);
    }

    const passwordHash = await hashPassword(password);
    try {
      const rows = await sql`
        INSERT INTO users (email, password_hash, name, auth_provider)
        VALUES (${email}, ${passwordHash}, ${name}, 'email')
        RETURNING id, email, name, avatar_url, auth_provider, created_at
      `;

      const user = UserPublicSchema.parse(rows[0]);
      const token = signJwt({ sub: user.id, email: user.email, name: user.name });

      return successResponse({ user, token }, 201);
    } catch (error) {
      if (isUniqueViolation(error)) {
        return conflict("An account with this email already exists", undefined, request);
      }
      throw error;
    }
  } catch (error) {
    return apiError(error, "Failed to register user", request);
  }
}
