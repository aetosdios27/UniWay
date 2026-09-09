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

// Long-lived processes (self-hosted / warm serverless instances) otherwise accumulate one
// Map entry per unique client forever. Sweeping is O(map size), so it's time-gated rather
// than run on every request.
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

export function withRateLimit(
  request: Request,
  config?: RateLimitConfig
): NextResponse | null {
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const result = checkRateLimit(ip, config);

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
