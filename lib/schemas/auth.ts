import { z } from "zod";

export const UserPublicSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().trim().min(1),
  avatar_url: z.string().url().nullable().optional(),
  auth_provider: z.enum(["email", "google"]),
  created_at: z.string().or(z.date()).transform((val) => (typeof val === "string" ? val : val.toISOString())),
});

export type UserPublic = z.infer<typeof UserPublicSchema>;

export const RegisterRequestSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(8, "Password must be at least 8 characters"),
  name: z.string().trim().min(1, "Name cannot be empty").max(100),
});

export type RegisterRequest = z.infer<typeof RegisterRequestSchema>;

export const LoginRequestSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1, "Password is required"),
});

export type LoginRequest = z.infer<typeof LoginRequestSchema>;

export const GoogleAuthRequestSchema = z.object({
  idToken: z.string().trim().min(1, "Google ID token is required"),
});

export type GoogleAuthRequest = z.infer<typeof GoogleAuthRequestSchema>;

export const AuthResponseSchema = z.object({
  user: UserPublicSchema,
  token: z.string(),
});

export type AuthResponse = z.infer<typeof AuthResponseSchema>;
