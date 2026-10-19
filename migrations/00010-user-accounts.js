export async function up(sql) {
  await sql`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT,
      name TEXT NOT NULL,
      avatar_url TEXT,
      auth_provider TEXT NOT NULL CHECK (auth_provider IN ('email', 'google')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `;

  await sql`CREATE INDEX IF NOT EXISTS users_email_lower_idx ON users (lower(email))`;
}

export async function down(sql) {
  await sql`DROP INDEX IF EXISTS users_email_lower_idx`;
  await sql`DROP TABLE IF EXISTS users`;
}
