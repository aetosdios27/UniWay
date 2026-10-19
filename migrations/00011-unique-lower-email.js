export async function up(sql) {
  await sql`DROP INDEX IF EXISTS users_email_lower_idx`;
  await sql`CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_unique_idx ON users (lower(email))`;
}

export async function down(sql) {
  await sql`DROP INDEX IF EXISTS users_email_lower_unique_idx`;
  await sql`CREATE INDEX IF NOT EXISTS users_email_lower_idx ON users (lower(email))`;
}
