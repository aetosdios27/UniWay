import { apiError, badRequest, formatZodError, successResponse, unauthorized, validateBodySize } from "@/lib/api-response";
import { signJwt, verifyGoogleIdToken } from "@/lib/auth";
import { sql } from "@/lib/db";
import { withRateLimit } from "@/lib/rate-limit";
import { GoogleAuthRequestSchema, UserPublicSchema } from "@/lib/schemas/auth";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const rateLimitResponse = withRateLimit(request, { maxRequests: 15, windowMs: 60_000 });
  if (rateLimitResponse) return rateLimitResponse;

  const sizeCheck = await validateBodySize(request, 10_240);
  if (!sizeCheck.ok) return sizeCheck.response;

  try {
    const rawBody = JSON.parse(sizeCheck.body);
    const parsed = GoogleAuthRequestSchema.safeParse(rawBody);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodError(parsed.error), undefined, request);
    }

    const { idToken } = parsed.data;
    const googleUser = await verifyGoogleIdToken(idToken);
    if (!googleUser) {
      return unauthorized("Invalid or expired Google token", undefined, request);
    }

    const { email, name, picture } = googleUser;

    const existingRows = await sql`
      SELECT id, email, name, avatar_url, auth_provider, created_at
      FROM users
      WHERE lower(email) = ${email}
      LIMIT 1
    `;

    let userRow;
    if (existingRows.length > 0) {
      const updated = await sql`
        UPDATE users
        SET avatar_url = COALESCE(${picture || null}, avatar_url),
            password_hash = NULL,
            auth_provider = 'google',
            updated_at = now()
        WHERE id = ${existingRows[0].id}
        RETURNING id, email, name, avatar_url, auth_provider, created_at
      `;
      userRow = updated[0];
    } else {
      const created = await sql`
        INSERT INTO users (email, name, avatar_url, auth_provider)
        VALUES (${email}, ${name}, ${picture || null}, 'google')
        RETURNING id, email, name, avatar_url, auth_provider, created_at
      `;
      userRow = created[0];
    }

    const user = UserPublicSchema.parse(userRow);
    const token = signJwt({ sub: user.id, email: user.email, name: user.name });

    return successResponse({ user, token });
  } catch (error) {
    return apiError(error, "Failed to authenticate with Google", request);
  }
}
