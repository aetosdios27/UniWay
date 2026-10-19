import { describe, it, expect, vi } from "vitest";
import {
  ApiErrorCode,
  badRequest,
  conflict,
  notFound,
  apiError,
  unauthorized,
  validateBodySize,
} from "@/lib/api-response";

vi.mock("@/lib/logger", () => ({ createLogger: () => ({ warn: vi.fn(), error: vi.fn(), info: vi.fn() }) }));
vi.mock("@sentry/nextjs", () => ({ captureException: vi.fn() }));

describe("ApiErrorCode constants", () => {
  const validCodes = Object.values(ApiErrorCode);

  it("all codes are non-empty strings", () => {
    for (const code of validCodes) {
      expect(typeof code).toBe("string");
      expect(code.length).toBeGreaterThan(0);
    }
  });
});

describe("badRequest", () => {
  it("returns 400 with BAD_REQUEST code by default", async () => {
    const res = badRequest("invalid input");
    const json = await res.json();
    expect(res.status).toBe(400);
    expect(json.code).toBe(ApiErrorCode.BAD_REQUEST);
  });

  it("accepts an explicit error code", async () => {
    const res = badRequest("validation error", undefined, ApiErrorCode.VALIDATION_ERROR);
    const json = await res.json();
    expect(json.code).toBe(ApiErrorCode.VALIDATION_ERROR);
  });
});

describe("notFound", () => {
  it("returns 404 with NOT_FOUND code", async () => {
    const res = notFound("resource not found");
    const json = await res.json();
    expect(res.status).toBe(404);
    expect(json.code).toBe(ApiErrorCode.NOT_FOUND);
  });
});

describe("unauthorized", () => {
  it("returns 401 with the UNAUTHORIZED code and request id", async () => {
    const res = unauthorized();
    const json = await res.json();
    expect(res.status).toBe(401);
    expect(json.code).toBe(ApiErrorCode.UNAUTHORIZED);
    expect(json.error).toBe("Unauthorized");
    expect(res.headers.get("X-Request-Id")).toBe(json.requestId);
  });

  it("keeps a caller-supplied message without echoing credentials", async () => {
    const res = unauthorized("Invalid email or password");
    const json = await res.json();
    expect(json.error).toBe("Invalid email or password");
  });
});

describe("conflict", () => {
  it("returns 409 with the CONFLICT code", async () => {
    const res = conflict("An account with this email already exists");
    const json = await res.json();
    expect(res.status).toBe(409);
    expect(json.code).toBe(ApiErrorCode.CONFLICT);
  });
});

describe("apiError", () => {
  it("returns 500 with INTERNAL_ERROR code", async () => {
    const res = apiError(new Error("test"), "test context");
    const json = await res.json();
    expect(res.status).toBe(500);
    expect(json.code).toBe(ApiErrorCode.INTERNAL_ERROR);
  });
});

describe("validateBodySize", () => {
  it("returns PAYLOAD_TOO_LARGE code for oversized body", async () => {
    const largeBody = "x".repeat(20_000);
    const request = new Request("http://localhost", { method: "POST", body: largeBody });
    const result = await validateBodySize(request, 10_240);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      const json = await result.response.json();
      expect(json.code).toBe(ApiErrorCode.PAYLOAD_TOO_LARGE);
    }
  });

  it("returns ok for small body", async () => {
    const request = new Request("http://localhost", { method: "POST", body: JSON.stringify({ test: true }) });
    const result = await validateBodySize(request, 10_240);
    expect(result.ok).toBe(true);
  });
});
