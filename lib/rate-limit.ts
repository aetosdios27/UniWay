import { NextResponse } from "next/server";

const requestCounts = new Map<string, { count: number; resetAt: number }>();

export interface RateLimitConfig {
  maxRequests: number;
  windowMs: number;
}

const defaultConfig: RateLimitConfig = {
  maxRequests: 100,
  windowMs: 60_000,
};

const SWEEP_INTERVAL_MS = 60_000;
let lastSweep = Date.now();

function sweepExpired(now: number): void {
  if (now - lastSweep < SWEEP_INTERVAL_MS) return;
  lastSweep = now;
  for (const [key, entry] of requestCounts) {
    if (now > entry.resetAt) requestCounts.delete(key);
  }
}

function checkRateLimit(
  key: string,
  config: RateLimitConfig = defaultConfig
): { allowed: boolean; remaining: number; resetAt: number } {
  const now = Date.now();
  sweepExpired(now);
  const entry = requestCounts.get(key);

  if (!entry || now > entry.resetAt) {
    requestCounts.set(key, { count: 1, resetAt: now + config.windowMs });
    return { allowed: true, remaining: config.maxRequests - 1, resetAt: now + config.windowMs };
  }

  if (entry.count >= config.maxRequests) {
    return { allowed: false, remaining: 0, resetAt: entry.resetAt };
  }

  entry.count++;
  return { allowed: true, remaining: config.maxRequests - entry.count, resetAt: entry.resetAt };
}

function clientKeyOf(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  if (forwarded) return forwarded;
  const realIp = request.headers.get("x-real-ip")?.trim();
  if (realIp) return realIp;
  return "unknown-local";
}

export function withRateLimit(
  request: Request,
  config?: RateLimitConfig
): NextResponse | null {
  return checkKey(clientKeyOf(request), config);
}

// Keyed limiter for identities narrower than the client address, e.g.
// `login:${email}` so a brute-forcer cannot rotate client addresses to bypass a per-IP limit.
export function withKeyedRateLimit(
  key: string,
  config?: RateLimitConfig
): NextResponse | null {
  return checkKey(key, config);
}

function checkKey(key: string, config?: RateLimitConfig): NextResponse | null {
  const result = checkRateLimit(key, config);

  if (!result.allowed) {
    return NextResponse.json(
      { error: "Too many requests" },
      {
        status: 429,
        headers: {
          "Retry-After": String(Math.ceil((result.resetAt - Date.now()) / 1000)),
          "X-RateLimit-Remaining": "0",
        },
      }
    );
  }

  return null;
}
