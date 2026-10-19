import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { GET as getMe } from "@/app/api/auth/me/route";
import { POST as googleAuth } from "@/app/api/auth/google/route";
import { POST as loginUser } from "@/app/api/auth/login/route";
import { POST as registerUser } from "@/app/api/auth/register/route";
import {
  hashPassword,
  signJwt,
  verifyGoogleIdToken,
  verifyJwt,
  verifyPassword,
} from "@/lib/auth";
import { sql } from "@/lib/db";
import { UserPublicSchema } from "@/lib/schemas/auth";

vi.mock("@/lib/db", () => ({
  sql: vi.fn(),
}));

describe("Authentication Library", () => {
  it("hashes passwords and verifies correctly", async () => {
    const password = "securePassword123!";
    const hash = await hashPassword(password);
    expect(hash).toContain(":");
    expect(await verifyPassword(password, hash)).toBe(true);
    expect(await verifyPassword("wrongPassword", hash)).toBe(false);
    expect(await verifyPassword(password, "invalid:format:extra")).toBe(false);
  });

  it("signs and verifies JWT tokens", () => {
    const payload = { sub: "123e4567-e89b-12d3-a456-426614174000", email: "test@example.com", name: "Test User" };
    const token = signJwt(payload);
    expect(token.split(".")).toHaveLength(3);

    const decoded = verifyJwt(token);
    expect(decoded?.sub).toBe(payload.sub);
    expect(decoded?.email).toBe(payload.email);
    expect(decoded?.name).toBe(payload.name);

    // Tampered token fails
    const tampered = token.slice(0, -5) + "abcde";
    expect(verifyJwt(tampered)).toBeNull();

    // Malformed token fails
    expect(verifyJwt("not.a.valid.token")).toBeNull();

    // Expired token fails
    const expiredToken = signJwt(payload, -10);
    expect(verifyJwt(expiredToken)).toBeNull();
  });

  it("verifies google tokens with tokeninfo endpoint", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          email: "student@example.com",
          name: "Campus Student",
          picture: "https://example.com/avatar.jpg",
          email_verified: "true",
        }),
        { status: 200 }
      )
    );

    const result = await verifyGoogleIdToken("valid_google_token");
    expect(result).toEqual({
      email: "student@example.com",
      name: "Campus Student",
      picture: "https://example.com/avatar.jpg",
    });

    fetchSpy.mockRestore();
  });

  it("rejects unverified google tokens", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ error_description: "Invalid Value" }), { status: 400 })
    );

    const result = await verifyGoogleIdToken("invalid_token");
    expect(result).toBeNull();
    fetchSpy.mockRestore();
  });

  it("fails closed in production when GOOGLE_CLIENT_ID is not configured", async () => {
    const prevId = process.env.GOOGLE_CLIENT_ID;
    delete process.env.GOOGLE_CLIENT_ID;
    vi.stubEnv("NODE_ENV", "production");

    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          email: "victim@example.com",
          name: "Victim",
          email_verified: "true",
          aud: "any-client-id",
        }),
        { status: 200 }
      )
    );

    try {
      const result = await verifyGoogleIdToken("valid_token_for_different_app");
      expect(result).toBeNull();
    } finally {
      fetchSpy.mockRestore();
      vi.unstubAllEnvs();
      if (prevId !== undefined) {
        process.env.GOOGLE_CLIENT_ID = prevId;
      } else {
        delete process.env.GOOGLE_CLIENT_ID;
      }
    }
  });

  it("accepts google token in production when audience matches GOOGLE_CLIENT_ID", async () => {
    const prevId = process.env.GOOGLE_CLIENT_ID;
    process.env.GOOGLE_CLIENT_ID = "uniway-client-id.apps.googleusercontent.com";
    vi.stubEnv("NODE_ENV", "production");

    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          email: "student@example.com",
          name: "Student",
          email_verified: "true",
          aud: "uniway-client-id.apps.googleusercontent.com",
        }),
        { status: 200 }
      )
    );

    try {
      const result = await verifyGoogleIdToken("valid_token");
      expect(result).toEqual({
        email: "student@example.com",
        name: "Student",
        picture: undefined,
      });
    } finally {
      fetchSpy.mockRestore();
      vi.unstubAllEnvs();
      if (prevId !== undefined) {
        process.env.GOOGLE_CLIENT_ID = prevId;
      } else {
        delete process.env.GOOGLE_CLIENT_ID;
      }
    }
  });
});

describe("Auth API Endpoints", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  const jsonRequest = (url: string, body: unknown, headers: Record<string, string> = {}) =>
    new Request(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify(body),
    });

  it("registers a new user successfully", async () => {
    const mockUser = {
      id: "123e4567-e89b-12d3-a456-426614174001",
      email: "newuser@example.com",
      name: "New User",
      avatar_url: null,
      auth_provider: "email",
      created_at: new Date().toISOString(),
    };

    const mockSql = sql as unknown as ReturnType<typeof vi.fn>;
    mockSql.mockResolvedValueOnce([]); // no existing user
    mockSql.mockResolvedValueOnce([mockUser]); // insert result

    const req = jsonRequest("http://localhost/api/auth/register", {
      email: "newuser@example.com",
      password: "password123",
      name: "New User",
    });

    const res = await registerUser(req);
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.data.user.email).toBe("newuser@example.com");
    expect(body.data.token).toBeTypeOf("string");
  });

  it("rejects registration with existing email", async () => {
    const mockSql = sql as unknown as ReturnType<typeof vi.fn>;
    mockSql.mockResolvedValueOnce([{ id: "existing-id" }]);

    const req = jsonRequest("http://localhost/api/auth/register", {
      email: "existing@example.com",
      password: "password123",
      name: "Existing",
    });

    const res = await registerUser(req);
    expect(res.status).toBe(409);
    const body = await res.json();
    expect(body.error).toContain("already exists");
  });

  it("rejects weak password on registration", async () => {
    const req = jsonRequest("http://localhost/api/auth/register", {
      email: "weak@example.com",
      password: "short",
      name: "Weak Pass",
    });

    const res = await registerUser(req);
    expect(res.status).toBe(400);
  });

  it("logs in an existing user with correct credentials", async () => {
    const password = "mySecretPassword123";
    const passwordHash = await hashPassword(password);

    const mockUser = {
      id: "123e4567-e89b-12d3-a456-426614174002",
      email: "user@example.com",
      password_hash: passwordHash,
      name: "Existing User",
      avatar_url: null,
      auth_provider: "email",
      created_at: new Date().toISOString(),
    };

    const mockSql = sql as unknown as ReturnType<typeof vi.fn>;
    mockSql.mockResolvedValueOnce([mockUser]);

    const req = jsonRequest("http://localhost/api/auth/login", {
      email: "user@example.com",
      password,
    });

    const res = await loginUser(req);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.user.email).toBe("user@example.com");
    expect(body.data.token).toBeTypeOf("string");
  });

  it("rejects login with wrong password", async () => {
    const passwordHash = await hashPassword("correctPassword");

    const mockUser = {
      id: "123e4567-e89b-12d3-a456-426614174002",
      email: "user@example.com",
      password_hash: passwordHash,
      name: "User",
      avatar_url: null,
      auth_provider: "email",
      created_at: new Date().toISOString(),
    };

    const mockSql = sql as unknown as ReturnType<typeof vi.fn>;
    mockSql.mockResolvedValueOnce([mockUser]);

    const req = jsonRequest("http://localhost/api/auth/login", {
      email: "user@example.com",
      password: "wrongPassword",
    });

    const res = await loginUser(req);
    expect(res.status).toBe(401);
  });

  it("authenticates via google token", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          email: "googleuser@example.com",
          name: "Google Student",
          picture: "https://example.com/pic.jpg",
          email_verified: "true",
        }),
        { status: 200 }
      )
    );

    const mockUser = {
      id: "123e4567-e89b-12d3-a456-426614174003",
      email: "googleuser@example.com",
      name: "Google Student",
      avatar_url: "https://example.com/pic.jpg",
      auth_provider: "google",
      created_at: new Date().toISOString(),
    };

    const mockSql = sql as unknown as ReturnType<typeof vi.fn>;
    mockSql.mockResolvedValueOnce([]); // no existing user
    mockSql.mockResolvedValueOnce([mockUser]); // insert result

    const req = jsonRequest("http://localhost/api/auth/google", {
      idToken: "valid_token_sample",
    });

    const res = await googleAuth(req);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.user.email).toBe("googleuser@example.com");
    expect(body.data.user.avatar_url).toBe("https://example.com/pic.jpg");
  });

  it("fetches current user profile via /api/auth/me", async () => {
    const userId = "123e4567-e89b-12d3-a456-426614174004";
    const token = signJwt({ sub: userId, email: "me@example.com", name: "Me" });

    const mockUser = {
      id: userId,
      email: "me@example.com",
      name: "Me",
      avatar_url: null,
      auth_provider: "email",
      created_at: new Date().toISOString(),
    };

    const mockSql = sql as unknown as ReturnType<typeof vi.fn>;
    mockSql.mockResolvedValueOnce([mockUser]);

    const req = new Request("http://localhost/api/auth/me", {
      headers: { Authorization: `Bearer ${token}` },
    });

    const res = await getMe(req);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.user.id).toBe(userId);
  });

  it("rejects /api/auth/me with invalid or missing token", async () => {
    const req = new Request("http://localhost/api/auth/me");
    const res = await getMe(req);
    expect(res.status).toBe(401);
  });
});

describe("Auth API edge cases", () => {
  const mockSql = () => sql as unknown as ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.resetAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // Each request uses its own client address so in-memory rate-limit buckets cannot leak
  // counts between tests; tests that exercise the limiter itself pass an explicit ip.
  let clientIpCounter = 0;
  const authRequest = (
    path: string,
    body: unknown,
    { ip = `192.0.2.${++clientIpCounter}`, headers = {} }: { ip?: string; headers?: Record<string, string> } = {}
  ) =>
    new Request(`http://localhost${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-forwarded-for": ip,
        ...headers,
      },
      body: typeof body === "string" ? body : JSON.stringify(body),
    });

  const validUser = (overrides: Record<string, unknown> = {}) => ({
    id: "123e4567-e89b-12d3-a456-426614174010",
    email: "student@example.com",
    name: "Campus Student",
    avatar_url: null,
    auth_provider: "email",
    created_at: new Date().toISOString(),
    ...overrides,
  });

  describe("POST /api/auth/register", () => {
    it("normalizes a mixed-case email before lookup and insert", async () => {
      mockSql().mockResolvedValueOnce([]).mockResolvedValueOnce([validUser({ email: "mixed@example.com" })]);

      const res = await registerUser(
        authRequest("/api/auth/register", {
          email: "  Mixed@Example.COM ",
          password: "password123",
          name: "Mixed Case",
        })
      );

      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.data.user.email).toBe("mixed@example.com");

      // The SELECT receives the trimmed, lower-cased address, so the case-insensitive
      // duplicate check cannot be bypassed with capitalization.
      expect(mockSql().mock.calls[0][1]).toBe("mixed@example.com");
    });

    it("rejects a duplicate email regardless of casing with 409", async () => {
      mockSql().mockResolvedValueOnce([{ id: "existing-id" }]);

      const res = await registerUser(
        authRequest("/api/auth/register", {
          email: "EXISTING@Example.com",
          password: "password123",
          name: "Existing",
        })
      );

      expect(res.status).toBe(409);
      const body = await res.json();
      expect(body.code).toBe("CONFLICT");
      expect(mockSql().mock.calls[0][1]).toBe("existing@example.com");
    });

    it("returns field-level validation errors for an invalid payload", async () => {
      const res = await registerUser(
        authRequest("/api/auth/register", { email: "not-an-email", password: "short", name: "   " })
      );

      expect(res.status).toBe(400);
      const body = await res.json();
      expect(body.code).toBe("BAD_REQUEST");
      const fields = (body.details as { field: string }[]).map((detail) => detail.field);
      expect(fields).toEqual(expect.arrayContaining(["email", "password", "name"]));
    });

    it("rejects an oversized request body with 413", async () => {
      const res = await registerUser(
        authRequest("/api/auth/register", {
          email: "student@example.com",
          password: "p".repeat(11_000),
          name: "Large Body",
        })
      );

      expect(res.status).toBe(413);
      const body = await res.json();
      expect(body.code).toBe("PAYLOAD_TOO_LARGE");
    });

    it("returns 500 without leaking details when the database fails", async () => {
      mockSql().mockRejectedValueOnce(new Error("connection refused: postgres://secret"));

      const res = await registerUser(
        authRequest("/api/auth/register", {
          email: "student@example.com",
          password: "password123",
          name: "Campus Student",
        })
      );

      expect(res.status).toBe(500);
      const body = await res.json();
      expect(body.code).toBe("INTERNAL_ERROR");
      expect(body.error).toBe("Internal Server Error");
      expect(body.error).not.toContain("postgres");
    });

    it("maps a concurrent duplicate insert to a 409 instead of a 500", async () => {
      // Both racers pass the pre-check; the unique lower(email) index rejects the insert.
      mockSql().mockResolvedValueOnce([]).mockRejectedValueOnce({ code: "23505" });

      const res = await registerUser(
        authRequest("/api/auth/register", {
          email: "race@example.com",
          password: "password123",
          name: "Racer",
        })
      );

      expect(res.status).toBe(409);
      const body = await res.json();
      expect(body.code).toBe("CONFLICT");

      const wrapped = new Error("insert failed", { cause: { code: "23505" } as unknown as Error });
      mockSql().mockResolvedValueOnce([]).mockRejectedValueOnce(wrapped);
      const wrappedRes = await registerUser(
        authRequest("/api/auth/register", {
          email: "race-wrapped@example.com",
          password: "password123",
          name: "Racer Two",
        })
      );
      expect(wrappedRes.status).toBe(409);
    });

    it("rate limits repeated registration attempts with 429", async () => {
      const ip = "203.0.113.42";
      for (let attempt = 0; attempt < 10; attempt++) {
        const res = await registerUser(
          authRequest("/api/auth/register", { email: "bad", password: "bad", name: "" }, { ip })
        );
        expect(res.status).toBe(400);
      }

      const limited = await registerUser(
        authRequest("/api/auth/register", { email: "bad", password: "bad", name: "" }, { ip })
      );
      expect(limited.status).toBe(429);
      expect(limited.headers.get("Retry-After")).toBeTruthy();
    });
  });

  describe("POST /api/auth/login", () => {
    it("rejects an unknown email with a generic 401", async () => {
      mockSql().mockResolvedValueOnce([]);

      const res = await loginUser(
        authRequest("/api/auth/login", { email: "nobody@example.com", password: "password123" })
      );

      expect(res.status).toBe(401);
      const body = await res.json();
      expect(body.code).toBe("UNAUTHORIZED");
      expect(body.error).toBe("Invalid email or password");
    });

    it("rejects invalid credentials payloads before touching the database", async () => {
      const res = await loginUser(
        authRequest("/api/auth/login", { email: "not-an-email", password: "" })
      );

      expect(res.status).toBe(400);
      expect(mockSql()).not.toHaveBeenCalled();
    });

    it("treats a Google-only account like any other unknown credential with a generic 401", async () => {
      mockSql().mockResolvedValueOnce([
        validUser({ auth_provider: "google", password_hash: null }),
      ]);

      const res = await loginUser(
        authRequest("/api/auth/login", { email: "google-only-1@example.com", password: "password123" })
      );

      // The endpoint must not confirm which emails hold accounts (enumeration), so the
      // did-not-register-a-password hint is intentionally absent.
      expect(res.status).toBe(401);
      const body = await res.json();
      expect(body.error).toBe("Invalid email or password");
    });

    it("limits repeated credential guesses on one account regardless of client address", async () => {
      const googleOnlyUser = validUser({ auth_provider: "google", password_hash: null });
      for (let attempt = 0; attempt < 8; attempt++) {
        mockSql().mockResolvedValueOnce([googleOnlyUser]);
        const res = await loginUser(
          authRequest(
            "/api/auth/login",
            { email: "bruteforce@example.com", password: "password123" },
            { ip: `198.51.100.${attempt + 60}` }
          )
        );
        expect(res.status).toBe(401);
      }

      const limited = await loginUser(
        authRequest(
          "/api/auth/login",
          { email: "bruteforce@example.com", password: "password123" },
          { ip: "198.51.100.199" }
        )
      );
      expect(limited.status).toBe(429);
    });

    it("returns 500 when the user lookup throws", async () => {
      mockSql().mockRejectedValueOnce(new Error("timeout"));

      const res = await loginUser(
        authRequest("/api/auth/login", { email: "student@example.com", password: "password123" })
      );

      expect(res.status).toBe(500);
    });
  });

  describe("POST /api/auth/google", () => {
    const googleTokenResponse = (overrides: Record<string, unknown> = {}) =>
      new Response(
        JSON.stringify({
          email: "student@example.com",
          name: "Campus Student",
          picture: "https://example.com/avatar.jpg",
          email_verified: "true",
          iss: "https://accounts.google.com",
          ...overrides,
        }),
        { status: 200 }
      );

    it("requires an idToken", async () => {
      const res = await googleAuth(authRequest("/api/auth/google", {}, { ip: "198.51.100.21" }));

      expect(res.status).toBe(400);
    });

    it("rejects a token Google does not consider valid", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
        new Response(JSON.stringify({ error_description: "Invalid Value" }), { status: 400 })
      );

      const res = await googleAuth(
        authRequest("/api/auth/google", { idToken: "bad" }, { ip: "198.51.100.22" })
      );

      expect(res.status).toBe(401);
    });

    it("updates the avatar of an existing account instead of creating a new one", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(googleTokenResponse());

      mockSql()
        .mockResolvedValueOnce([validUser({ auth_provider: "google" })])
        .mockResolvedValueOnce([
          validUser({ auth_provider: "google", avatar_url: "https://example.com/avatar.jpg" }),
        ]);

      const res = await googleAuth(
        authRequest("/api/auth/google", { idToken: "valid" }, { ip: "198.51.100.23" })
      );

      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.data.user.avatar_url).toBe("https://example.com/avatar.jpg");
      expect(mockSql().mock.calls).toHaveLength(2);
    });

    it("clears any pre-existing password_hash when linking an existing account to prevent pre-hijacking", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(googleTokenResponse());

      mockSql()
        .mockResolvedValueOnce([validUser({ auth_provider: "email" })])
        .mockResolvedValueOnce([
          validUser({ auth_provider: "google", avatar_url: "https://example.com/avatar.jpg" }),
        ]);

      const res = await googleAuth(
        authRequest("/api/auth/google", { idToken: "valid" }, { ip: "198.51.100.23" })
      );

      expect(res.status).toBe(200);
      const updateCall = mockSql().mock.calls[1];
      const sqlStrings = (updateCall[0] as string[]).join(" ");
      expect(sqlStrings).toContain("password_hash = NULL");
      expect(sqlStrings).toContain("auth_provider = 'google'");
    });

    it("returns 500 when persisting the Google account fails", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(googleTokenResponse());
      mockSql().mockRejectedValueOnce(new Error("insert failed"));

      const res = await googleAuth(
        authRequest("/api/auth/google", { idToken: "valid" }, { ip: "198.51.100.24" })
      );

      expect(res.status).toBe(500);
    });
  });

  describe("GET /api/auth/me", () => {
    const meRequest = (authorization?: string, ip = "198.51.100.50") =>
      new Request("http://localhost/api/auth/me", {
        headers: {
          "x-forwarded-for": ip,
          ...(authorization ? { Authorization: authorization } : {}),
        },
      });

    it("rejects an expired token with 401", async () => {
      const token = signJwt(
        { sub: "123e4567-e89b-12d3-a456-426614174011", email: "me@example.com", name: "Me" },
        -60
      );

      const res = await getMe(meRequest(`Bearer ${token}`));

      expect(res.status).toBe(401);
      expect(mockSql()).not.toHaveBeenCalled();
    });

    it("rejects a malformed bearer token with 401", async () => {
      for (const header of ["Bearer not-a-jwt", "Basic dXNlcjpwYXNz", "Bearer ", "Bearer a.b.c"]) {
        const res = await getMe(meRequest(header));
        expect(res.status).toBe(401);
      }
    });

    it("rejects a token whose user no longer exists", async () => {
      const token = signJwt({
        sub: "123e4567-e89b-12d3-a456-426614174012",
        email: "deleted@example.com",
        name: "Deleted",
      });
      mockSql().mockResolvedValueOnce([]);

      const res = await getMe(meRequest(`Bearer ${token}`));

      expect(res.status).toBe(401);
    });

    it("rejects a token without a subject", async () => {
      const token = signJwt({ sub: "", email: "me@example.com", name: "Me" });

      const res = await getMe(meRequest(`Bearer ${token}`));

      expect(res.status).toBe(401);
      expect(mockSql()).not.toHaveBeenCalled();
    });

    it("returns 500 when the user lookup throws", async () => {
      const token = signJwt({
        sub: "123e4567-e89b-12d3-a456-426614174013",
        email: "me@example.com",
        name: "Me",
      });
      mockSql().mockRejectedValueOnce(new Error("db unavailable"));

      const res = await getMe(meRequest(`Bearer ${token}`));

      expect(res.status).toBe(500);
    });

    it("rate limits profile polling per client", async () => {
      const ip = "203.0.113.90";
      for (let attempt = 0; attempt < 30; attempt++) {
        const res = await getMe(meRequest(undefined, ip));
        expect(res.status).toBe(401);
      }

      const limited = await getMe(meRequest(undefined, ip));
      expect(limited.status).toBe(429);
    });
  });
});

describe("Auth schema and library hardening", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
  });

  it("normalizes the created_at date branch to an ISO string", () => {
    const parsed = UserPublicSchema.parse({
      id: "123e4567-e89b-12d3-a456-426614174014",
      email: "student@example.com",
      name: "Student",
      avatar_url: null,
      auth_provider: "email",
      created_at: new Date("2026-01-02T03:04:05.000Z"),
    });

    expect(parsed.created_at).toBe("2026-01-02T03:04:05.000Z");
  });

  it("resolves false instead of throwing for corrupted stored hashes", async () => {
    expect(await verifyPassword("password123", "")).toBe(false);
    expect(await verifyPassword("password123", "missing-separator")).toBe(false);
    expect(await verifyPassword("password123", "nothex:nothex")).toBe(false);
    expect(await verifyPassword("password123", "a:b:c")).toBe(false);
  });

  it("rejects non-hex and truncated salts and keys", async () => {
    const hash = await hashPassword("password123");
    const [salt, key] = hash.split(":");
    expect(await verifyPassword("password123", `${salt}:${key}zz`)).toBe(false);
    expect(await verifyPassword("password123", `${salt}:${key.slice(0, 8)}`)).toBe(false);
  });

  it("rejects a Google token when email_verified is false", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ email: "s@example.com", email_verified: false }), { status: 200 })
    );

    expect(await verifyGoogleIdToken("token")).toBeNull();
  });

  it("rejects a Google token with a missing email", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ email_verified: "true" }), { status: 200 })
    );

    expect(await verifyGoogleIdToken("token")).toBeNull();
  });

  it("rejects a Google token from an untrusted issuer", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          email: "s@example.com",
          email_verified: "true",
          iss: "https://evil.example.com",
        }),
        { status: 200 }
      )
    );

    expect(await verifyGoogleIdToken("token")).toBeNull();
  });

  it("rejects a Google token minted for a different client when GOOGLE_CLIENT_ID is set", async () => {
    vi.stubEnv("GOOGLE_CLIENT_ID", "uniway.apps.googleusercontent.com");
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          email: "s@example.com",
          email_verified: "true",
          iss: "https://accounts.google.com",
          aud: "someone-elses-app.apps.googleusercontent.com",
        }),
        { status: 200 }
      )
    );

    expect(await verifyGoogleIdToken("token")).toBeNull();
  });

  it("accepts a Google token for the configured client and lower-cases the email", async () => {
    vi.stubEnv("GOOGLE_CLIENT_ID", "uniway.apps.googleusercontent.com");
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          email: "Student@Example.COM",
          email_verified: "true",
          iss: "accounts.google.com",
          aud: "uniway.apps.googleusercontent.com",
        }),
        { status: 200 }
      )
    );

    const result = await verifyGoogleIdToken("token");

    expect(result?.email).toBe("student@example.com");
    // Falls back to the email local-part when Google omits a display name.
    expect(result?.name).toBe("student");
  });

  it("returns null instead of throwing when the Google endpoint is unreachable", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValueOnce(new Error("network down"));

    expect(await verifyGoogleIdToken("token")).toBeNull();
  });
});

describe("AUTH_SECRET production guard", () => {
  it("refuses to start in production without AUTH_SECRET", async () => {
    const previousSecret = process.env.AUTH_SECRET;
    delete process.env.AUTH_SECRET;
    vi.stubEnv("NODE_ENV", "production");
    try {
      vi.resetModules();
      await expect(import("@/lib/auth")).rejects.toThrow(/AUTH_SECRET/);
    } finally {
      vi.unstubAllEnvs();
      if (previousSecret !== undefined) {
        process.env.AUTH_SECRET = previousSecret;
      }
      vi.resetModules();
    }
  });

  it("falls back to an insecure dev secret outside production and mints working tokens", async () => {
    const previousSecret = process.env.AUTH_SECRET;
    delete process.env.AUTH_SECRET;
    vi.stubEnv("NODE_ENV", "test");
    try {
      vi.resetModules();
      const { signJwt: devSignJwt, verifyJwt: devVerifyJwt } = await import("@/lib/auth");
      const token = devSignJwt({ sub: "sub", email: "e@example.com", name: "E" });
      expect(devVerifyJwt(token)?.sub).toBe("sub");
    } finally {
      vi.unstubAllEnvs();
      if (previousSecret !== undefined) {
        process.env.AUTH_SECRET = previousSecret;
      }
      vi.resetModules();
    }
  });
});
