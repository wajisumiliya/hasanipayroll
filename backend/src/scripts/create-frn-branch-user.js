import "dotenv/config";
import crypto from "node:crypto";
import bcrypt from "bcryptjs";
import pg from "pg";

const { Pool } = pg;
const usernames = [
  "HPSPFRN",
  "HBSPFRN",
  "HBAMJFRN",
  "HBASFRN",
  "HBASTANAFRN",
  "HBGURUNFRN",
  "HBJITRAFRN",
  "HBPERAIFRN",
  "HBKULIMFRN",
  "HBLKWFRN",
];
const password = process.env.FRN_BRANCH_PASSWORD || "Hasanifrn123";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

try {
  const passwordHash = await bcrypt.hash(password, 12);

  for (const username of usernames) {
    const email = `${username.toLowerCase()}@hasani.local`;
    await pool.query(
      `
        INSERT INTO public."app_user" (
          "id", "username", "email", "passwordHash", "role",
          "isActive", "mustChangePassword", "createdAt", "updatedAt"
        )
        VALUES ($1, $2, $3, $4, 'BRANCH', TRUE, FALSE, NOW(), NOW())
        ON CONFLICT ("email") DO UPDATE SET
          "username" = EXCLUDED."username",
          "passwordHash" = EXCLUDED."passwordHash",
          "role" = 'BRANCH',
          "isActive" = TRUE,
          "mustChangePassword" = FALSE,
          "updatedAt" = NOW()
      `,
      [crypto.randomUUID(), username, email, passwordHash],
    );
  }

  console.log(`FRN branch accounts created or updated: ${usernames.length}`);
} finally {
  await pool.end();
}
