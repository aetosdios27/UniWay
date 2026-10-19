import crypto from "node:crypto";
import { sql } from "@/lib/db";
import { UserPublicSchema, type UserPublic } from "@/lib/schemas/auth";
import singletonLogger from "@/lib/logger";

let AUTH_SECRET = process.env.AUTH_SECRET || "";

if (!AUTH_SECRET) {
  const isProductionBuild = process.env.NEXT_PHASE === "phase-production-build";
  if (process.env.NODE_ENV === "production" && !isProductionBuild) {
    throw new Error(
      "AUTH_SECRET must be configured in production; refusing to start with the built-in fallback secret."
    );
  }
  singletonLogger.warn(
    "AUTH_SECRET is not configured; falling back to an insecure built-in secret. Set it before deploying."
  );
  AUTH_SECRET = "uniway-default-secret-key-change-in-production";
}

export function hashPassword(password: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const salt = crypto.randomBytes(SALT_BYTES);
    crypto.scrypt(password, salt, KEY_BYTES, (err, derivedKey) => {
      if (err) return reject(err);
      resolve(`${salt.toString("hex")}:${derivedKey.toString("hex")}`);
    });
  });
}

const HEX_PATTERN = /^[0-9a-f]+$/i;
const SALT_BYTES = 16;
const KEY_BYTES = 64;

const DUMMY_HASH_SALT = crypto.randomBytes(SALT_BYTES).toString("hex");
export const DUMMY_PASSWORD_HASH = `${DUMMY_HASH_SALT}:${crypto
  .scryptSync("", Buffer.from(DUMMY_HASH_SALT, "hex"), KEY_BYTES)
  .toString("hex")}`;

export function verifyPassword(password: string, storedHash: string): Promise<boolean> {
  return new Promise((resolve) => {
    const parts = storedHash.split(":");
    if (parts.length !== 2) return resolve(false);
    const [saltHex, keyHex] = parts;
    if (!HEX_PATTERN.test(saltHex) || !HEX_PATTERN.test(keyHex)) return resolve(false);
    if (saltHex.length !== SALT_BYTES * 2 || keyHex.length !== KEY_BYTES * 2) return resolve(false);

    const salt = Buffer.from(saltHex, "hex");
    const expectedKey = Buffer.from(keyHex, "hex");

    crypto.scrypt(password, salt, expectedKey.length, (err, derivedKey) => {
      if (err) return resolve(false);
      try {
        resolve(crypto.timingSafeEqual(expectedKey, derivedKey));
      } catch {
        resolve(false);
      }
    });
  });
}

function base64UrlEncode(str: string): string {
  return Buffer.from(str)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function base64UrlDecode(str: string): string {
  let base64 = str.replace(/-/g, "+").replace(/_/g, "/");
  while (base64.length % 4) {
    base64 += "=";
  }
  return Buffer.from(base64, "base64").toString("utf8");
}

export interface JwtPayload {
  sub: string;
  email: string;
  name: string;
  iat?: number;
  exp?: number;
}

export function signJwt(payload: JwtPayload, expiresInSeconds = 7 * 24 * 3600): string {
  const now = Math.floor(Date.now() / 1000);
  const fullPayload: JwtPayload = {
    ...payload,
    iat: now,
    exp: now + expiresInSeconds,
  };

  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const encodedPayload = base64UrlEncode(JSON.stringify(fullPayload));
  const data = `${header}.${encodedPayload}`;

  const signature = crypto
    .createHmac("sha256", AUTH_SECRET)
    .update(data)
    .digest("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${data}.${signature}`;
}

export function verifyJwt(token: string): JwtPayload | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const [header, payload, signature] = parts;
    const data = `${header}.${payload}`;

    const expectedSignature = crypto
      .createHmac("sha256", AUTH_SECRET)
      .update(data)
      .digest("base64")
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

    const sigBuf = Buffer.from(signature);
    const expectedBuf = Buffer.from(expectedSignature);
    if (sigBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(sigBuf, expectedBuf)) {
      return null;
    }

    const decoded = JSON.parse(base64UrlDecode(payload)) as JwtPayload;
    const now = Math.floor(Date.now() / 1000);
    if (decoded.exp && decoded.exp < now) {
      return null;
    }

    return decoded;
  } catch {
    return null;
  }
}

export async function verifyGoogleIdToken(
  idToken: string
): Promise<{ email: string; name: string; picture?: string } | null> {
  try {
    const response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
    );
    if (!response.ok) return null;
    const data = (await response.json()) as {
      email?: string;
      name?: string;
      picture?: string;
      email_verified?: string | boolean;
      aud?: string;
      iss?: string;
    };

    if (!data.email || !(data.email_verified === true || data.email_verified === "true")) {
      return null;
    }

    const validIssuer =
      data.iss === undefined || data.iss === "accounts.google.com" || data.iss === "https://accounts.google.com";
    if (!validIssuer) return null;

    const googleClientId = process.env.GOOGLE_CLIENT_ID;
    if (googleClientId) {
      if (data.aud !== googleClientId) return null;
    } else {
      if (process.env.NODE_ENV === "production") {
        singletonLogger.error(
          "GOOGLE_CLIENT_ID is not configured in production; refusing to verify Google ID token without audience validation."
        );
        return null;
      }
      singletonLogger.warn(
        "GOOGLE_CLIENT_ID is not configured; Google ID token audience is not being verified."
      );
    }

    const email = data.email.toLowerCase();
    return {
      email,
      name: data.name || email.split("@")[0],
      picture: data.picture,
    };
  } catch (error) {
    singletonLogger.error("Failed to verify Google token", { error: String(error) });
    return null;
  }
}

export async function getAuthenticatedUser(request: Request): Promise<UserPublic | null> {
  const authHeader = request.headers.get("authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;

  const token = authHeader.slice(7).trim();
  const payload = verifyJwt(token);
  if (!payload || !payload.sub) return null;

  const rows = await sql`
    SELECT id, email, name, avatar_url, auth_provider, created_at
    FROM users
    WHERE id = ${payload.sub}
    LIMIT 1
  `;
  if (!rows.length) return null;
  return UserPublicSchema.parse(rows[0]);
}
