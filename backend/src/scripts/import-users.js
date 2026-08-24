import fs from "fs";
import path from "path";
import crypto from "crypto";
import bcrypt from "bcryptjs";
import pg from "pg";
import dotenv from "dotenv";

dotenv.config();

const { Pool } = pg;

/*
|--------------------------------------------------------------------------
| HASANI PAYROLL - USER IMPORT
|--------------------------------------------------------------------------
|
| JSON source:
|   backend/data/users.json
|
| Temporary password for every imported user:
|   112233
|
| Database table:
|   public."app_user"
|
| Existing database columns:
|   id
|   employeeId
|   username
|   email
|   passwordHash
|   role
|   isActive
|   mustChangePassword
|   passwordChangedAt
|   otpHash
|   otpExpiresAt
|   otpAttempts
|   otpLastSentAt
|   otpVerifiedAt
|   lastLoginAt
|   createdAt
|   updatedAt
|--------------------------------------------------------------------------
*/

const USERS_FILE = path.resolve(
  process.cwd(),
  "data",
  "users.json"
);

const COMMON_PASSWORD = "112233";

const ROLE_MAP = {
  employee: "EMPLOYEE",
  admin: "ADMIN",
  branch: "BRANCH",
};

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

/**
 * Generate UUID for app_user.id.
 *
 * This fixes:
 *   null value in column "id" of relation "app_user"
 *
 * because the existing table does not have a database default for id.
 */
function generateId() {
  return crypto.randomUUID();
}

/**
 * Clean username.
 *
 * The first JSON record contains:
 *   " smnliyana@gmail.com"
 *
 * so we trim leading/trailing spaces.
 */
function cleanUsername(value) {
  if (value === null || value === undefined) {
    return null;
  }

  return String(value).trim();
}

/**
 * Clean optional employee ID.
 */
function cleanEmployeeId(value) {
  if (value === null || value === undefined) {
    return null;
  }

  const result = String(value).trim();

  return result === "" ? null : result;
}

/**
 * Clean display name.
 */
function cleanDisplayName(value, username) {
  if (value === null || value === undefined) {
    return username;
  }

  const result = String(value).trim();

  return result === "" ? username : result;
}

/**
 * Determine email.
 *
 * The current database has both username and email.
 *
 * For normal employee records, username is already an email.
 * For branch accounts such as ALOR SETAR, there is no email in JSON,
 * so email is set to the username.
 *
 * This avoids NULL email problems if the column is NOT NULL or unique.
 */
function getEmail(username) {
  return username;
}

/**
 * Convert JSON role into PostgreSQL enum value.
 */
function mapRole(role) {
  if (!role) {
    throw new Error("Missing role");
  }

  const normalized = String(role).trim().toLowerCase();

  const mapped = ROLE_MAP[normalized];

  if (!mapped) {
    throw new Error(
      `Unsupported role "${role}". Expected employee, admin, or branch.`
    );
  }

  return mapped;
}

/**
 * Read users.json.
 */
function loadUsers() {
  console.log(`Users file: ${USERS_FILE}`);

  if (!fs.existsSync(USERS_FILE)) {
    throw new Error(`Users file not found: ${USERS_FILE}`);
  }

  const raw = fs.readFileSync(USERS_FILE, "utf8");

  let users;

  try {
    users = JSON.parse(raw);
  } catch (error) {
    throw new Error(
      `users.json contains invalid JSON: ${error.message}`
    );
  }

  if (!Array.isArray(users)) {
    throw new Error("users.json must contain a JSON array.");
  }

  return users;
}

/**
 * Test database connection.
 */
async function testDatabase() {
  console.log("");
  console.log("Testing PostgreSQL connection...");

  const client = await pool.connect();

  try {
    const result = await client.query(`
      SELECT
        current_database() AS database,
        current_user AS user
    `);

    console.log(
      `Connected to database: ${result.rows[0].database}`
    );

    console.log(
      `PostgreSQL user: ${result.rows[0].user}`
    );
  } finally {
    client.release();
  }
}

/**
 * Get app_user columns.
 */
async function getTableColumns(client) {
  const result = await client.query(`
    SELECT
      column_name,
      data_type,
      udt_name,
      is_nullable,
      column_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'app_user'
    ORDER BY ordinal_position
  `);

  return result.rows;
}

/**
 * Verify the existing table.
 *
 * IMPORTANT:
 * We use the actual Prisma-style camelCase columns:
 *
 *   employeeId
 *   passwordHash
 *   isActive
 *   mustChangePassword
 */
async function checkTable(client) {
  console.log("");
  console.log("Checking public.app_user table...");

  const columns = await getTableColumns(client);

  if (columns.length === 0) {
    throw new Error(
      'Table public."app_user" does not exist.'
    );
  }

  console.log("");
  console.log("Actual columns found:");

  for (const column of columns) {
    console.log(`  - ${column.column_name}`);
  }

  const actual = new Set(
    columns.map((column) => column.column_name)
  );

  const required = [
    "id",
    "employeeId",
    "username",
    "email",
    "passwordHash",
    "role",
    "isActive",
    "mustChangePassword",
    "createdAt",
    "updatedAt",
  ];

  const missing = required.filter(
    (column) => !actual.has(column)
  );

  if (missing.length > 0) {
    throw new Error(
      `The public.app_user table is missing required columns:\n\n` +
      missing.map((column) => `  - ${column}`).join("\n")
    );
  }

  console.log("");
  console.log("Required columns verified.");

  return columns;
}

/**
 * Check PostgreSQL UserRole enum.
 */
async function checkRoleEnum(client) {
  console.log("");
  console.log('Checking PostgreSQL enum "UserRole"...');

  const result = await client.query(`
    SELECT
      e.enumlabel
    FROM pg_type t
    JOIN pg_enum e
      ON t.oid = e.enumtypid
    JOIN pg_namespace n
      ON n.oid = t.typnamespace
    WHERE t.typname = 'UserRole'
      AND n.nspname = 'public'
    ORDER BY e.enumsortorder
  `);

  const values = result.rows.map(
    (row) => row.enumlabel
  );

  if (values.length === 0) {
    throw new Error(
      'PostgreSQL enum "UserRole" was not found.'
    );
  }

  console.log(
    `UserRole enum values: ${values.join(", ")}`
  );

  const requiredRoles = [
    "ADMIN",
    "EMPLOYEE",
    "BRANCH",
  ];

  const missingRoles = requiredRoles.filter(
    (role) => !values.includes(role)
  );

  if (missingRoles.length > 0) {
    throw new Error(
      `UserRole enum is missing:\n` +
      missingRoles.map((role) => `  - ${role}`).join("\n")
    );
  }

  return values;
}

/**
 * Check whether username already exists.
 */
async function findExistingUser(client, username) {
  const result = await client.query(
    `
      SELECT
        id,
        "employeeId",
        username,
        email,
        role,
        "isActive",
        "mustChangePassword"
      FROM public."app_user"
      WHERE username = $1
      LIMIT 1
    `,
    [username]
  );

  return result.rows[0] || null;
}

/**
 * Check whether employeeId already exists.
 */
async function findExistingEmployee(client, employeeId) {
  if (!employeeId) {
    return null;
  }

  const result = await client.query(
    `
      SELECT
        id,
        "employeeId",
        username,
        email,
        role
      FROM public."app_user"
      WHERE "employeeId" = $1
      LIMIT 1
    `,
    [employeeId]
  );

  return result.rows[0] || null;
}

/**
 * Import users.
 */
async function importUsers() {
  console.log("==============================================");
  console.log(" HASANI PAYROLL - USER IMPORT");
  console.log("==============================================");
  console.log("");

  console.log(`Users file: ${USERS_FILE}`);

  if (!process.env.DATABASE_URL) {
    throw new Error(
      "DATABASE_URL is missing from environment variables."
    );
  }

  console.log("Database configuration: DATABASE_URL");

  const users = loadUsers();

  console.log(`Users found in JSON: ${users.length}`);

  if (users.length === 0) {
    throw new Error("No users found in users.json.");
  }

  await testDatabase();

  const client = await pool.connect();

  let inserted = 0;
  let updated = 0;
  let skipped = 0;

  try {
    await checkTable(client);

    await checkRoleEnum(client);

    console.log("");
    console.log("Generating password hash...");

    /*
     * One common password for all imported users.
     *
     * We store ONLY the bcrypt hash in the database.
     */
    const passwordHash = await bcrypt.hash(
      COMMON_PASSWORD,
      12
    );

    console.log("Password hash generated.");

    console.log("");
    console.log(
      `Common temporary password: ${COMMON_PASSWORD}`
    );

    console.log("");
    console.log("Role mapping:");
    console.log("  employee -> EMPLOYEE");
    console.log("  admin -> ADMIN");
    console.log("  branch -> BRANCH");

    console.log("");
    console.log("Database column mapping:");
    console.log("  employee_id  -> employeeId");
    console.log("  display_name -> email / display name handling");
    console.log("  is_active    -> isActive");
    console.log("  first_login  -> mustChangePassword");
    console.log("  password     -> passwordHash");

    console.log("");
    console.log("Starting database transaction...");

    await client.query("BEGIN");

    try {
      /*
       * We validate every record before modifying the database.
       */
      console.log("");
      console.log("Validating users...");

      const normalizedUsers = [];

      const usernameSet = new Set();
      const employeeIdSet = new Set();

      for (let i = 0; i < users.length; i++) {
        const source = users[i];

        const rowNumber = i + 1;

        const username = cleanUsername(
          source.username
        );

        if (!username) {
          throw new Error(
            `Row ${rowNumber}: username is required.`
          );
        }

        const role = mapRole(source.role);

        const employeeId = cleanEmployeeId(
          source.employee_id
        );

        const displayName = cleanDisplayName(
          source.display_name,
          username
        );

        const isActive =
          source.is_active === undefined
            ? true
            : Boolean(source.is_active);

        /*
         * JSON first_login=true means:
         * user must change password after first login.
         */
        const mustChangePassword =
          source.first_login === undefined
            ? true
            : Boolean(source.first_login);

        const email = getEmail(username);

        /*
         * Detect duplicate usernames inside JSON.
         */
        const usernameKey = username.toLowerCase();

        if (usernameSet.has(usernameKey)) {
          throw new Error(
            `Duplicate username in JSON: ${username}`
          );
        }

        usernameSet.add(usernameKey);

        /*
         * Detect duplicate employee IDs inside JSON.
         *
         * Branches/admins can have NULL employeeId.
         */
        if (employeeId) {
          if (employeeIdSet.has(employeeId)) {
            throw new Error(
              `Duplicate employee_id in JSON: ${employeeId}`
            );
          }

          employeeIdSet.add(employeeId);
        }

        normalizedUsers.push({
          source,
          username,
          email,
          role,
          employeeId,
          displayName,
          isActive,
          mustChangePassword,
        });
      }

      console.log(
        `Validation successful: ${normalizedUsers.length} users.`
      );

      /*
       * Import each user.
       *
       * IMPORTANT:
       *
       * We deliberately generate a UUID for id.
       *
       * The database currently has:
       *
       *   id NOT NULL
       *
       * but no default value.
       *
       * Therefore PostgreSQL cannot generate it automatically.
       */
      for (let i = 0; i < normalizedUsers.length; i++) {
        const user = normalizedUsers[i];

        const progress = `${i + 1}/${normalizedUsers.length}`;

        /*
         * First match by username.
         */
        const existingByUsername =
          await findExistingUser(
            client,
            user.username
          );

        /*
         * If employeeId is supplied, make sure it isn't
         * already assigned to another username.
         */
        const existingByEmployee =
          user.employeeId
            ? await findExistingEmployee(
                client,
                user.employeeId
              )
            : null;

        if (
          existingByEmployee &&
          existingByUsername &&
          String(existingByEmployee.id) !==
            String(existingByUsername.id)
        ) {
          throw new Error(
            `Employee ID conflict for ${user.employeeId}: ` +
            `already belongs to ${existingByEmployee.username}, ` +
            `but JSON assigns it to ${user.username}.`
          );
        }

        if (existingByUsername) {
          /*
           * UPDATE existing account.
           *
           * We intentionally reset the password to 112233
           * and mark the account as needing a password change.
           */
          await client.query(
            `
              UPDATE public."app_user"
              SET
                "employeeId" = $1,
                email = $2,
                "passwordHash" = $3,
                role = $4::"UserRole",
                "isActive" = $5,
                "mustChangePassword" = $6,
                "passwordChangedAt" = NULL,
                "updatedAt" = NOW()
              WHERE id = $7
            `,
            [
              user.employeeId,
              user.email,
              passwordHash,
              user.role,
              user.isActive,
              user.mustChangePassword,
              existingByUsername.id,
            ]
          );

          updated++;

          console.log(
            `[${progress}] UPDATED  ${user.username} -> ${user.role}`
          );
        } else {
          /*
           * INSERT new account.
           *
           * Generate id ourselves because the current table
           * does not provide a default for id.
           */
          const id = generateId();

          await client.query(
            `
              INSERT INTO public."app_user" (
                id,
                "employeeId",
                username,
                email,
                "passwordHash",
                role,
                "isActive",
                "mustChangePassword",
                "passwordChangedAt",
                "otpHash",
                "otpExpiresAt",
                "otpAttempts",
                "otpLastSentAt",
                "otpVerifiedAt",
                "lastLoginAt",
                "createdAt",
                "updatedAt"
              )
              VALUES (
                $1,
                $2,
                $3,
                $4,
                $5,
                $6::"UserRole",
                $7,
                $8,
                NULL,
                NULL,
                NULL,
                0,
                NULL,
                NULL,
                NULL,
                NOW(),
                NOW()
              )
            `,
            [
              id,
              user.employeeId,
              user.username,
              user.email,
              passwordHash,
              user.role,
              user.isActive,
              user.mustChangePassword,
            ]
          );

          inserted++;

          console.log(
            `[${progress}] INSERTED ${user.username} -> ${user.role}`
          );
        }
      }

      await client.query("COMMIT");

      console.log("");
      console.log("Transaction committed successfully.");
    } catch (error) {
      await client.query("ROLLBACK");

      console.log("");
      console.log(
        "Transaction rolled back because an error occurred."
      );

      throw error;
    }
  } finally {
    client.release();
  }

  /*
   * Final summary.
   */
  console.log("");
  console.log("==============================================");
  console.log(" USER IMPORT COMPLETED");
  console.log("==============================================");
  console.log("");
  console.log(`Users in JSON : ${users.length}`);
  console.log(`Inserted      : ${inserted}`);
  console.log(`Updated       : ${updated}`);
  console.log(`Skipped       : ${skipped}`);
  console.log("");
  console.log("Temporary password for imported users:");
  console.log(`  ${COMMON_PASSWORD}`);
  console.log("");
  console.log(
    "Users marked with mustChangePassword=true will be required"
  );
  console.log(
    "to change the temporary password after first login."
  );
  console.log("");
}

/**
 * Run.
 */
importUsers()
  .catch((error) => {
    console.error("");
    console.error("==============================================");
    console.error(" USER IMPORT FAILED");
    console.error("==============================================");

    console.error(error);

    console.error("==============================================");

    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });