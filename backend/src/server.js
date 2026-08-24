import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import express from "express";
import cors from "cors";
import pg from "pg";
import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

import nodemailer from "nodemailer";

// ============================================================
// ENVIRONMENT
// ============================================================

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({
  path: path.join(__dirname, "../.env"),
});

// ============================================================
// APP
// ============================================================

const app = express();

app.use(
  cors({
    origin: true,
    credentials: true,
  }),
);





app.use(cors({
  origin: '*', // Or specify 'https://hasanihub.onrender.com'
  credentials: true
}));



app.use(
  express.json({
    limit: "10mb",
  }),
);



// ============================================================
// DATABASE
// ============================================================

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const adapter = new PrismaPg(pool);

const prisma = new PrismaClient({
  adapter,
});

// ============================================================
// DATABASE TEST
// ============================================================

async function testDatabase() {
  try {
    const connection = await pool.query(`
      SELECT
        current_database(),
        current_schema()
    `);

    console.log(
      "CONNECTED DATABASE:",
      connection.rows[0],
    );

    const tables = await pool.query(`
      SELECT
        table_schema,
        table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);

    console.log("PUBLIC TABLES:");
    console.table(tables.rows);

    const columns = await pool.query(`
      SELECT
        column_name,
        data_type
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'app_user'
      ORDER BY ordinal_position
    `);

    console.log("APP_USER COLUMNS:");
    console.table(columns.rows);

    const users = await pool.query(`
      SELECT COUNT(*)::int AS count
      FROM public."app_user"
    `);

    console.log(
      "APP_USER COUNT:",
      users.rows[0].count,
    );
  } catch (error) {
    console.error(
      "DATABASE CONNECTION ERROR:",
      error,
    );
  }
}

testDatabase();

// ============================================================
// HELPERS
// ============================================================

function normalizeLogin(value) {
  return String(value ?? "").trim();
}

function normalizeEmployeeId(value) {
  return normalizeLogin(value).toUpperCase();
}

function numberValue(value) {
  if (
    value === null ||
    value === undefined ||
    value === ""
  ) {
    return 0;
  }

  const cleaned = String(value)
    .replace(/RM/gi, "")
    .replace(/,/g, "")
    .trim();

  const result = Number(cleaned);

  return Number.isFinite(result)
    ? result
    : 0;
}

// ============================================================
// PASSWORD VERIFICATION
// ============================================================
//
// Supports:
//
// 1. bcrypt hash
// 2. legacy plain-text password
//
// Recommended: migrate all passwords to bcrypt.
//

async function verifyPassword(
  enteredPassword,
  storedPassword,
) {
  if (
    !enteredPassword ||
    !storedPassword
  ) {
    return false;
  }

  const stored =
    String(storedPassword).trim();

  // bcrypt
  if (
    stored.startsWith("$2a$") ||
    stored.startsWith("$2b$") ||
    stored.startsWith("$2y$")
  ) {
    try {
      return await bcrypt.compare(
        enteredPassword,
        stored,
      );
    } catch (error) {
      console.error(
        "BCRYPT ERROR:",
        error,
      );

      return false;
    }
  }

  // Legacy plain text
  return enteredPassword === stored;
}

// ============================================================
// FIND APP USER
// ============================================================
//
// ACTUAL TABLE:
//
// public."app_user"
//
// ACTUAL COLUMNS:
//
// username
// email
// passwordHash
// role
// isActive
// employeeId
// mustChangePassword
// otpHash
// otpExpiresAt
// ...
//
// ============================================================

async function findAppUser(login) {
  const cleanLogin =
    normalizeLogin(login);

  if (!cleanLogin) {
    return null;
  }

  const employeeId =
    normalizeEmployeeId(cleanLogin);

  const result = await pool.query(
    `
    SELECT
      "id",
      "employeeId",
      "username",
      "email",
      "passwordHash",
      "role",
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
    FROM public."app_user"
    WHERE
      LOWER(TRIM(COALESCE("username", ''))) =
      LOWER(TRIM($1))
      OR
      LOWER(TRIM(COALESCE("email", ''))) =
      LOWER(TRIM($1))
      OR
      UPPER(TRIM(COALESCE("employeeId", ''))) =
      $2
    LIMIT 1
    `,
    [
      cleanLogin,
      employeeId,
    ],
  );

  if (result.rows.length === 0) {
    return null;
  }

  return result.rows[0];
}

// ============================================================
// GET EMPLOYEE
// ============================================================

async function getEmployeeByEmployeeId(
  employeeId,
) {
  if (!employeeId) {
    return null;
  }

  try {
    return await prisma.employee.findUnique({
      where: {
        employeeId:
          normalizeEmployeeId(
            employeeId,
          ),
      },
    });
  } catch (error) {
    console.error(
      "EMPLOYEE LOOKUP ERROR:",
      error.message,
    );

    return null;
  }
}

// ============================================================
// PUBLIC USER
// ============================================================

async function publicAppUser(user) {
  const role =
    String(user.role ?? "")
      .trim()
      .toLowerCase();

  const employee =
    user.employeeId
      ? await getEmployeeByEmployeeId(
          user.employeeId,
        )
      : null;

  return {
    id:
      user.id ?? null,

    username:
      user.username ?? "",

    email:
      user.email ?? null,

    role,

    employeeId:
      user.employeeId ?? null,

    displayName:
      employee?.name ??
      user.username ??
      "",

    isActive:
      user.isActive === true,

    firstLogin:
      user.mustChangePassword === true,

    mustChangePassword:
      user.mustChangePassword === true,

    employee,

    isAdmin:
      role === "admin",

    isBranch:
      role === "branch",

    isEmployee:
      role === "employee",
  };
}

// ============================================================
// ROOT
// ============================================================

app.get("/", (req, res) => {
  res.json({
    name: "Hasani Payroll API",
    status: "online",
    version: "4.0.0",
  });
});

// ============================================================
// HEALTH
// ============================================================

app.get(
  "/health",
  async (req, res) => {
    try {
      await pool.query(
        "SELECT 1",
      );

      const result =
        await pool.query(`
          SELECT COUNT(*)::int AS count
          FROM public."app_user"
        `);

      return res.json({
        ok: true,
        database: "connected",
        appUsers:
          result.rows[0].count,
        message:
          "Hasani Payroll API is running",
        time:
          new Date().toISOString(),
      });
    } catch (error) {
      console.error(
        "HEALTH ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        database: "disconnected",
        message:
          error.message,
      });
    }
  },
);

// ============================================================
// DEBUG APP USERS
// ============================================================
//
// NEVER returns passwords.
//

app.get(
  "/api/debug/app-users",
  async (req, res) => {
    try {
      const result =
        await pool.query(`
          SELECT
            "id",
            "username",
            "email",
            "role",
            "employeeId",
            "isActive",
            "mustChangePassword",
            "createdAt"
          FROM public."app_user"
          ORDER BY "username"
        `);

      return res.json({
        ok: true,
        count:
          result.rows.length,
        users:
          result.rows,
      });
    } catch (error) {
      console.error(
        "DEBUG USERS ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          error.message,
      });
    }
  },
);

// ============================================================
// LOGIN
// ============================================================

app.post(
  "/api/auth/login",
  async (req, res) => {
    try {
      const username =
        normalizeLogin(
          req.body?.username,
        );

      const password =
        String(
          req.body?.password ?? "",
        );

      console.log(
        "LOGIN REQUEST:",
        username,
      );

      if (!username) {
        return res.status(400).json({
          ok: false,
          message:
            "Username, email or Employee ID is required.",
        });
      }

      if (!password) {
        return res.status(400).json({
          ok: false,
          message:
            "Password is required.",
        });
      }

      // ------------------------------------------
      // FIND USER
      // ------------------------------------------

      const user =
        await findAppUser(
          username,
        );

      if (!user) {
        console.log(
          "USER NOT FOUND:",
          username,
        );

        return res.status(401).json({
          ok: false,
          message:
            "Invalid username or password.",
        });
      }

      console.log(
        "USER FOUND:",
        {
          id:
            user.id,
          username:
            user.username,
          email:
            user.email,
          employeeId:
            user.employeeId,
          role:
            user.role,
          isActive:
            user.isActive,
          mustChangePassword:
            user.mustChangePassword,
        },
      );

      // ------------------------------------------
      // ACTIVE
      // ------------------------------------------

      if (user.isActive !== true) {
        return res.status(403).json({
          ok: false,
          message:
            "This account is inactive.",
        });
      }

      // ------------------------------------------
      // PASSWORD
      // ------------------------------------------

      const passwordMatches =
        await verifyPassword(
          password,
          user.passwordHash,
        );

      if (!passwordMatches) {
        console.log(
          "PASSWORD FAILED:",
          username,
        );

        return res.status(401).json({
          ok: false,
          message:
            "Invalid username or password.",
        });
      }

      // ------------------------------------------
      // UPDATE LOGIN
      // ------------------------------------------

      await pool.query(
        `
        UPDATE public."app_user"
        SET
          "lastLoginAt" = NOW(),
          "updatedAt" = NOW()
        WHERE "id" = $1
        `,
        [
          user.id,
        ],
      );

      // ------------------------------------------
      // SAFE USER
      // ------------------------------------------

      const safeUser =
        await publicAppUser(
          user,
        );

      console.log(
        "LOGIN SUCCESS:",
        user.username,
      );

      return res.json({
        ok: true,

        message:
          "Login successful.",

        firstLogin:
          user.mustChangePassword === true,

        requiresOtp:
          false,

        user:
          safeUser,
      });
    } catch (error) {
      console.error(
        "LOGIN ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          "Login failed.",
        error:
          error.message,
      });
    }
  },
);

// ============================================================
// GET CURRENT USER
// ============================================================

app.get(
  "/api/auth/user/:username",
  async (req, res) => {
    try {
      const username =
        normalizeLogin(
          req.params.username,
        );

      const user =
        await findAppUser(
          username,
        );

      if (!user) {
        return res.status(404).json({
          ok: false,
          message:
            "User not found.",
        });
      }

      if (user.isActive !== true) {
        return res.status(403).json({
          ok: false,
          message:
            "This account is inactive.",
        });
      }

      const safeUser =
        await publicAppUser(
          user,
        );

      return res.json({
        ok: true,
        user:
          safeUser,
      });
    } catch (error) {
      console.error(
        "GET USER ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          error.message,
      });
    }
  },
);

// ============================================================
// ADMIN - EMPLOYEES
// ============================================================

app.get(
  "/api/admin/employees",
  async (req, res) => {
    try {
      const employees =
        await prisma.employee.findMany({
          orderBy: {
            employeeId:
              "asc",
          },
        });

      return res.json({
        ok: true,
        count:
          employees.length,
        employees,
      });
    } catch (error) {
      console.error(
        "EMPLOYEE LIST ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          error.message,
      });
    }
  },
);

// ============================================================
// ADMIN - PAYROLL
// ============================================================

app.get(
  "/api/admin/payroll",
  async (req, res) => {
    try {
      const records =
        await prisma.payrollRecord.findMany({
          include: {
            employee: true,
          },
          orderBy: [
            {
              period:
                "desc",
            },
            {
              employeeId:
                "asc",
            },
          ],
        });

      return res.json({
        ok: true,
        count:
          records.length,
        payroll:
          records,
      });
    } catch (error) {
      console.error(
        "PAYROLL LIST ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          error.message,
      });
    }
  },
);

// ============================================================
// EMPLOYEE PAYROLL
// ============================================================

app.get(
  "/api/employees/:employeeId/payroll",
  async (req, res) => {
    try {
      const employeeId =
        normalizeEmployeeId(
          req.params.employeeId,
        );

      const employee =
        await prisma.employee.findUnique({
          where: {
            employeeId,
          },
        });

      if (!employee) {
        return res.status(404).json({
          ok: false,
          message:
            "Employee not found.",
        });
      }

      const payroll =
        await prisma.payrollRecord.findMany({
          where: {
            employeeId,
          },
          orderBy: {
            period:
              "desc",
          },
        });

      return res.json({
        ok: true,
        employee,
        count:
          payroll.length,
        payroll,
      });
    } catch (error) {
      console.error(
        "EMPLOYEE PAYROLL ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          error.message,
      });
    }
  },
);

// ============================================================
// SINGLE PAYSLIP
// ============================================================

app.get(
  "/api/employees/:employeeId/payroll/:year/:month",
  async (req, res) => {
    try {
      const employeeId =
        normalizeEmployeeId(
          req.params.employeeId,
        );

      const year =
        Number(
          req.params.year,
        );

      const month =
        Number(
          req.params.month,
        );

      if (
        !Number.isInteger(year) ||
        !Number.isInteger(month) ||
        month < 1 ||
        month > 12
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "Invalid year or month.",
        });
      }

      const startDate =
        new Date(
          Date.UTC(
            year,
            month - 1,
            1,
          ),
        );

      const endDate =
        new Date(
          Date.UTC(
            year,
            month,
            1,
          ),
        );

      const payroll =
        await prisma.payrollRecord.findFirst({
          where: {
            employeeId,

            period: {
              gte:
                startDate,
              lt:
                endDate,
            },
          },

          include: {
            employee: true,
          },
        });

      if (!payroll) {
        return res.status(404).json({
          ok: false,
          message:
            "Payslip not found.",
        });
      }

      return res.json({
        ok: true,
        payroll,
      });
    } catch (error) {
      console.error(
        "PAYSLIP ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          error.message,
      });
    }
  },
);

// ============================================================
// PAYROLL IMPORT
// ============================================================

app.post(
  "/api/admin/payroll/import",
  async (req, res) => {
    try {
      const rows =
        req.body?.rows;

      if (
        !Array.isArray(rows) ||
        rows.length === 0
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "No payroll rows received.",
        });
      }

      const results = {
        total:
          rows.length,
        imported: 0,
        updated: 0,
        errors: [],
      };

      for (
        let index = 0;
        index < rows.length;
        index++
      ) {
        const row =
          rows[index] ?? {};

        const rowNumber =
          index + 2;

        const employeeId =
          normalizeEmployeeId(
            row.employee_id ??
              row.employeeId ??
              "",
          );

        const periodText =
          String(
            row.period ?? "",
          ).trim();

        if (!employeeId) {
          results.errors.push({
            row:
              rowNumber,
            message:
              "Missing employee_id.",
          });

          continue;
        }

        if (!periodText) {
          results.errors.push({
            row:
              rowNumber,
            employeeId,
            message:
              "Missing payroll period.",
          });

          continue;
        }

        const period =
          new Date(
            periodText,
          );

        if (
          Number.isNaN(
            period.getTime(),
          )
        ) {
          results.errors.push({
            row:
              rowNumber,
            employeeId,
            message:
              `Invalid period: ${periodText}`,
          });

          continue;
        }

        const normalizedPeriod =
          new Date(
            Date.UTC(
              period.getUTCFullYear(),
              period.getUTCMonth(),
              1,
            ),
          );

        const employee =
          await prisma.employee.findUnique({
            where: {
              employeeId,
            },
          });

        if (!employee) {
          results.errors.push({
            row:
              rowNumber,
            employeeId,
            message:
              "Employee does not exist in database.",
          });

          continue;
        }

        const payrollData = {
          basicSalary:
            numberValue(
              row.basic_salary ??
                row.basicSalary,
            ),

          foodAllowance:
            numberValue(
              row.food_allowance ??
                row.foodAllowance,
            ),

          otherAllowance:
            numberValue(
              row.other_allowance ??
                row.otherAllowance,
            ),

          overtime:
            numberValue(
              row.overtime,
            ),

          bonus:
            numberValue(
              row.bonus,
            ),

          commission:
            numberValue(
              row.commission,
            ),

          otherEarnings:
            numberValue(
              row.other_earnings ??
                row.otherEarnings,
            ),

          epfEmployee:
            numberValue(
              row.epf_employee ??
                row.epfEmployee,
            ),

          socsoEmployee:
            numberValue(
              row.socso_employee ??
                row.socsoEmployee,
            ),

          eisEmployee:
            numberValue(
              row.eis_employee ??
                row.eisEmployee,
            ),

          pcb:
            numberValue(
              row.pcb,
            ),

          otherDeduction:
            numberValue(
              row.other_deduction ??
                row.otherDeduction,
            ),

          epfEmployer:
            numberValue(
              row.epf_employer ??
                row.epfEmployer,
            ),

          socsoEmployer:
            numberValue(
              row.socso_employer ??
                row.socsoEmployer,
            ),

          eisEmployer:
            numberValue(
              row.eis_employer ??
                row.eisEmployer,
            ),

          bankCode:
            String(
              row.bank_code ??
                row.bankCode ??
                employee.bankCode ??
                "",
            ),

          bankAccount:
            String(
              row.bank_account ??
                row.bankAccount ??
                employee.bankAccount ??
                "",
            ),

          remarks:
            row.remarks !==
              null &&
            row.remarks !==
              undefined &&
            String(
              row.remarks,
            ).trim() !== ""
              ? String(
                  row.remarks,
                )
              : null,
        };

        const existing =
          await prisma.payrollRecord.findUnique({
            where: {
              employeeId_period: {
                employeeId,
                period:
                  normalizedPeriod,
              },
            },
          });

        await prisma.payrollRecord.upsert({
          where: {
            employeeId_period: {
              employeeId,
              period:
                normalizedPeriod,
            },
          },

          update:
            payrollData,

          create: {
            employeeId,
            period:
              normalizedPeriod,
            ...payrollData,
          },
        });

        if (existing) {
          results.updated++;
        } else {
          results.imported++;
        }
      }

      return res.json({
        ok: true,
        message:
          "Payroll import completed.",
        ...results,
      });
    } catch (error) {
      console.error(
        "PAYROLL IMPORT ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          "Payroll import failed.",
        error:
          error.message,
      });
    }
  },
);

// ============================================================
// DELETE PAYROLL
// ============================================================

app.delete(
  "/api/admin/payroll/:id",
  async (req, res) => {
    try {
      await prisma.payrollRecord.delete({
        where: {
          id:
            req.params.id,
        },
      });

      return res.json({
        ok: true,
        message:
          "Payroll record deleted.",
      });
    } catch (error) {
      console.error(
        "DELETE PAYROLL ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,
        message:
          error.message,
      });
    }
  },
);

// ============================================================
// SERVER
// ============================================================

const port =
  Number(
    process.env.PORT || 5000,
  );

const server =
  app.listen(
    port,
    () => {
      console.log("");
      console.log(
        "========================================",
      );
      console.log(
        "HASANI PAYROLL API",
      );
      console.log(
        `http://localhost:${port}`,
      );
      console.log(
        "========================================",
      );
      console.log("");
    },
  );

// ============================================================
// SHUTDOWN
// ============================================================

async function shutdown() {
  console.log(
    "\nShutting down Hasani Payroll API...",
  );

  server.close(
    async () => {
      try {
        await prisma.$disconnect();
        await pool.end();
      } catch (error) {
        console.error(
          "Shutdown error:",
          error,
        );
      }

      process.exit(0);
    },
  );
}

process.on(
  "SIGINT",
  shutdown,
);

process.on(
  "SIGTERM",
  shutdown,
);
// ============================================================
// OTP CONFIGURATION
// ============================================================

const OTP_EXPIRES_MINUTES =
  Number(process.env.OTP_EXPIRES_MINUTES || 5);

const OTP_MAX_ATTEMPTS =
  Number(process.env.OTP_MAX_ATTEMPTS || 5);

const OTP_RESEND_SECONDS =
  Number(process.env.OTP_RESEND_SECONDS || 60);


// ============================================================
// SMTP
// ============================================================

const mailTransporter = nodemailer.createTransport({
  host:
    process.env.SMTP_HOST ||
    "smtp.gmail.com",

  port:
    Number(
      process.env.SMTP_PORT || 587,
    ),

  secure:
    String(
      process.env.SMTP_SECURE || "false",
    ).toLowerCase() === "true",

  auth: {
    user:
      String(
        process.env.SMTP_USER || "",
      ).trim(),

    pass:
      String(
        process.env.SMTP_PASSWORD || "",
      ),
  },
});


// ============================================================
// GENERATE OTP
// ============================================================

function generateOtp() {
  return String(
    Math.floor(
      100000 +
        Math.random() * 900000,
    ),
  );
}


// ============================================================
// SEND OTP EMAIL
// ============================================================

async function sendOtpEmail({
  email,
  name,
  otp,
}) {
  const from =
    process.env.SMTP_FROM ||
    process.env.SMTP_USER;

  await mailTransporter.sendMail({
    from,
    to: email,

    subject:
      "Hasani Payroll - First Login Verification",

    text: `
Hello ${name || "User"},

Your Hasani Payroll verification code is:

${otp}

This code will expire in ${OTP_EXPIRES_MINUTES} minutes.

If you did not request this code, please ignore this email.

Hasani Payroll
`,

    html: `
      <div
        style="
          font-family:Arial,sans-serif;
          max-width:600px;
          margin:auto;
          padding:20px;
        "
      >

        <h2 style="color:#15965D">
          Hasani Payroll
        </h2>

        <p>
          Hello ${name || "User"},
        </p>

        <p>
          Your first-login verification code is:
        </p>

        <div
          style="
            font-size:32px;
            font-weight:bold;
            letter-spacing:8px;
            padding:20px;
            background:#f3f4f6;
            text-align:center;
            border-radius:8px;
            margin:20px 0;
          "
        >
          ${otp}
        </div>

        <p>
          This code will expire in
          <strong>
            ${OTP_EXPIRES_MINUTES} minutes
          </strong>.
        </p>

        <p>
          If you did not request this code,
          please ignore this email.
        </p>

        <hr>

        <p
          style="
            color:#6b7280;
            font-size:12px;
          "
        >
          Hasani Payroll
        </p>

      </div>
    `,
  });
}


// ============================================================
// FIND USER FOR OTP
// ============================================================
//
// Accepts:
//
// username
// email
// employeeId
//
// This matches the Flutter application.
//

async function findOtpUser(value) {
  const cleanValue =
    normalizeLogin(value);

  if (!cleanValue) {
    return null;
  }

  return await findAppUser(
    cleanValue,
  );
}


// ============================================================
// SEND OTP
// ============================================================
//
// Flutter sends:
//
// {
//   employeeId: "..."
// }
//
// This endpoint also accepts:
//
// {
//   username: "..."
// }
//
// or:
//
// {
//   email: "..."
// }
//

app.post(
  "/api/auth/send-otp",
  async (req, res) => {
    try {
      const loginValue =
        normalizeLogin(
          req.body?.employeeId ??
          req.body?.username ??
          req.body?.email ??
          "",
        );

      if (!loginValue) {
        return res.status(400).json({
          ok: false,
          message:
            "Username, email or Employee ID is required.",
        });
      }

      console.log(
        "SEND OTP REQUEST:",
        loginValue,
      );

      // ------------------------------------------
      // FIND USER
      // ------------------------------------------

      const user =
        await findOtpUser(
          loginValue,
        );

      if (!user) {
        console.log(
          "OTP USER NOT FOUND:",
          loginValue,
        );

        return res.status(404).json({
          ok: false,
          message:
            "User not found.",
        });
      }

      console.log(
        "OTP USER FOUND:",
        {
          id:
            user.id,

          username:
            user.username,

          email:
            user.email,

          employeeId:
            user.employeeId,

          role:
            user.role,

          mustChangePassword:
            user.mustChangePassword,
        },
      );

      // ------------------------------------------
      // ACTIVE
      // ------------------------------------------

      if (user.isActive !== true) {
        return res.status(403).json({
          ok: false,
          message:
            "This account is inactive.",
        });
      }

      // ------------------------------------------
      // FIRST LOGIN CHECK
      // ------------------------------------------

      if (
        user.mustChangePassword !== true
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "First-login verification is not required for this account.",
        });
      }

      // ------------------------------------------
      // EMAIL
      // ------------------------------------------

      const email =
        String(
          user.email || "",
        ).trim();

      if (
        !email ||
        !email.includes("@")
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "This account does not have a valid registered email address.",
        });
      }

      // ------------------------------------------
      // RESEND LIMIT
      // ------------------------------------------

      if (user.otpLastSentAt) {
        const lastSent =
          new Date(
            user.otpLastSentAt,
          ).getTime();

        const elapsed =
          Date.now() -
          lastSent;

        const waitMs =
          OTP_RESEND_SECONDS *
          1000;

        if (elapsed < waitMs) {
          const remaining =
            Math.ceil(
              (waitMs - elapsed) /
                1000,
            );

          return res.status(429).json({
            ok: false,

            message:
              `Please wait ${remaining} seconds before requesting another OTP.`,

            retryAfter:
              remaining,
          });
        }
      }

      // ------------------------------------------
      // GENERATE OTP
      // ------------------------------------------

      const otp =
        generateOtp();

      console.log(
        "GENERATED OTP FOR:",
        user.username,
      );

      const otpHash =
        await bcrypt.hash(
          otp,
          10,
        );

      const expiresAt =
        new Date(
          Date.now() +
            OTP_EXPIRES_MINUTES *
              60 *
              1000,
        );

      // ------------------------------------------
      // SAVE OTP
      // ------------------------------------------

      await pool.query(
        `
        UPDATE public."app_user"
        SET
          "otpHash" = $1,
          "otpExpiresAt" = $2,
          "otpAttempts" = 0,
          "otpLastSentAt" = NOW(),
          "otpVerifiedAt" = NULL,
          "updatedAt" = NOW()
        WHERE "id" = $3
        `,
        [
          otpHash,
          expiresAt,
          user.id,
        ],
      );

      // ------------------------------------------
      // SEND EMAIL
      // ------------------------------------------

      try {
        await sendOtpEmail({
          email,

          name:
            user.username ||
            user.email ||
            "User",

          otp,
        });
      } catch (emailError) {
        console.error(
          "OTP EMAIL ERROR:",
          emailError,
        );

        // Remove OTP if email failed.
        await pool.query(
          `
          UPDATE public."app_user"
          SET
            "otpHash" = NULL,
            "otpExpiresAt" = NULL,
            "otpAttempts" = 0,
            "otpLastSentAt" = NULL,
            "updatedAt" = NOW()
          WHERE "id" = $1
          `,
          [
            user.id,
          ],
        );

        return res.status(500).json({
          ok: false,

          message:
            "Failed to send OTP email.",

          error:
            emailError.message,
        });
      }

      console.log(
        "OTP SENT:",
        {
          username:
            user.username,

          email,

          employeeId:
            user.employeeId,
        },
      );

      // ------------------------------------------
      // IMPORTANT
      //
      // Flutter expects otpId.
      //
      // We use the app_user ID as the OTP session
      // identifier because the database already
      // stores the OTP against this user.
      // ------------------------------------------

      return res.json({
        ok: true,

        message:
          "OTP has been sent to your registered email address.",

        otpId:
          String(user.id),

        employeeId:
          user.employeeId,

        username:
          user.username,

        email,

        expiresIn:
          OTP_EXPIRES_MINUTES *
          60,
      });
    } catch (error) {
      console.error(
        "SEND OTP ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,

        message:
          "Failed to send OTP.",

        error:
          error.message,
      });
    }
  },
);


// ============================================================
// FIND USER BY OTP ID
// ============================================================
//
// Flutter sends:
//
// {
//   otpId: "...",
//   otp: "123456"
// }
//

async function findUserByOtpId(
  otpId,
) {
  const cleanId =
    String(
      otpId ?? "",
    ).trim();

  if (!cleanId) {
    return null;
  }

  const result =
    await pool.query(
      `
      SELECT
        "id",
        "employeeId",
        "username",
        "email",
        "passwordHash",
        "role",
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
      FROM public."app_user"
      WHERE "id"::text = $1
      LIMIT 1
      `,
      [
        cleanId,
      ],
    );

  if (
    result.rows.length === 0
  ) {
    return null;
  }

  return result.rows[0];
}


// ============================================================
// VERIFY OTP
// ============================================================
//
// Accepts both:
//
// Flutter:
//
// {
//   otpId,
//   otp
// }
//
// Also supports:
//
// {
//   username,
//   otp
// }
//
// and:
//
// {
//   employeeId,
//   otp
// }
//

app.post(
  "/api/auth/verify-otp",
  async (req, res) => {
    try {
      const otp =
        String(
          req.body?.otp ?? "",
        ).trim();

      const otpId =
        String(
          req.body?.otpId ?? "",
        ).trim();

      const username =
        normalizeLogin(
          req.body?.username,
        );

      const employeeId =
        normalizeEmployeeId(
          req.body?.employeeId,
        );

      if (!/^\d{6}$/.test(otp)) {
        return res.status(400).json({
          ok: false,
          message:
            "OTP must be a 6-digit code.",
        });
      }

      let user = null;

      // ------------------------------------------
      // FIND BY OTP ID
      // ------------------------------------------

      if (otpId) {
        user =
          await findUserByOtpId(
            otpId,
          );
      }

      // ------------------------------------------
      // FALLBACK USERNAME / EMAIL
      // ------------------------------------------

      if (!user && username) {
        user =
          await findAppUser(
            username,
          );
      }

      // ------------------------------------------
      // FALLBACK EMPLOYEE ID
      // ------------------------------------------

      if (!user && employeeId) {
        user =
          await findAppUser(
            employeeId,
          );
      }

      if (!user) {
        return res.status(404).json({
          ok: false,
          message:
            "User or OTP session not found. Please login again and request a new OTP.",
        });
      }

      console.log(
        "VERIFY OTP REQUEST:",
        {
          username:
            user.username,

          employeeId:
            user.employeeId,

          otpId:
            otpId || null,
        },
      );

      // ------------------------------------------
      // ACTIVE
      // ------------------------------------------

      if (user.isActive !== true) {
        return res.status(403).json({
          ok: false,
          message:
            "This account is inactive.",
        });
      }

      // ------------------------------------------
      // FIRST LOGIN
      // ------------------------------------------

      if (
        user.mustChangePassword !== true
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "First-login verification is not required for this account.",
        });
      }

      // ------------------------------------------
      // OTP EXISTS
      // ------------------------------------------

      if (!user.otpHash) {
        return res.status(400).json({
          ok: false,
          message:
            "No OTP has been requested. Please request a new OTP.",
        });
      }

      // ------------------------------------------
      // OTP EXPIRY
      // ------------------------------------------

      if (
        !user.otpExpiresAt ||
        new Date(
          user.otpExpiresAt,
        ).getTime() <=
          Date.now()
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "OTP has expired. Please request a new OTP.",
        });
      }

      // ------------------------------------------
      // MAX ATTEMPTS
      // ------------------------------------------

      const attempts =
        Number(
          user.otpAttempts || 0,
        );

      if (
        attempts >=
        OTP_MAX_ATTEMPTS
      ) {
        return res.status(429).json({
          ok: false,
          message:
            "Maximum OTP attempts exceeded. Please request a new OTP.",
        });
      }

      // ------------------------------------------
      // VERIFY
      // ------------------------------------------

      const matches =
        await bcrypt.compare(
          otp,
          user.otpHash,
        );

      if (!matches) {
        await pool.query(
          `
          UPDATE public."app_user"
          SET
            "otpAttempts" =
              COALESCE("otpAttempts", 0) + 1,
            "updatedAt" = NOW()
          WHERE "id" = $1
          `,
          [
            user.id,
          ],
        );

        const remaining =
          Math.max(
            0,
            OTP_MAX_ATTEMPTS -
              attempts -
              1,
          );

        return res.status(401).json({
          ok: false,

          message:
            remaining > 0
              ? `Invalid OTP. ${remaining} attempt(s) remaining.`
              : "Invalid OTP. Maximum attempts exceeded.",

          attemptsRemaining:
            remaining,
        });
      }

      // ------------------------------------------
      // OTP SUCCESS
      // ------------------------------------------
      //
      // IMPORTANT:
      //
      // Do NOT remove otpVerifiedAt.
      //
      // completeFirstLogin() needs this field to
      // confirm that the OTP was successfully
      // verified before allowing password change.
      //

      await pool.query(
        `
        UPDATE public."app_user"
        SET
          "otpVerifiedAt" = NOW(),
          "otpHash" = NULL,
          "otpExpiresAt" = NULL,
          "otpAttempts" = 0,
          "updatedAt" = NOW()
        WHERE "id" = $1
        `,
        [
          user.id,
        ],
      );

      console.log(
        "OTP VERIFIED:",
        {
          username:
            user.username,

          employeeId:
            user.employeeId,
        },
      );

      const safeUser =
        await publicAppUser(
          user,
        );

      return res.json({
        ok: true,

        message:
          "OTP verified successfully.",

        verified:
          true,

        verificationId:
          String(user.id),

        employeeId:
          user.employeeId,

        username:
          user.username,

        user:
          safeUser,
      });
    } catch (error) {
      console.error(
        "VERIFY OTP ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,

        message:
          "OTP verification failed.",

        error:
          error.message,
      });
    }
  },
);


// ============================================================
// SET NEW PASSWORD
// ============================================================
//
// Flutter sends:
//
// {
//   verificationId: "...",
//   newPassword: "..."
// }
//
// This is used after successful OTP verification.
//

app.post(
  "/api/auth/set-password",
  async (req, res) => {
    try {
      const verificationId =
        String(
          req.body?.verificationId ?? "",
        ).trim();

      const newPassword =
        String(
          req.body?.newPassword ?? "",
        ).trim();

      if (!verificationId) {
        return res.status(400).json({
          ok: false,
          message:
            "Verification session is required.",
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({
          ok: false,
          message:
            "Password must contain at least 6 characters.",
        });
      }

      // ------------------------------------------
      // FIND USER
      // ------------------------------------------

      const user =
        await findUserByOtpId(
          verificationId,
        );

      if (!user) {
        return res.status(404).json({
          ok: false,
          message:
            "Verification session not found. Please login again.",
        });
      }

      // ------------------------------------------
      // ACTIVE
      // ------------------------------------------

      if (user.isActive !== true) {
        return res.status(403).json({
          ok: false,
          message:
            "This account is inactive.",
        });
      }

      // ------------------------------------------
      // FIRST LOGIN REQUIRED
      // ------------------------------------------

      if (
        user.mustChangePassword !== true
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "This account does not require first-login password setup.",
        });
      }

      // ------------------------------------------
      // VERIFY OTP WAS COMPLETED
      // ------------------------------------------

      if (!user.otpVerifiedAt) {
        return res.status(403).json({
          ok: false,
          message:
            "Please verify the OTP before creating your new password.",
        });
      }

      // ------------------------------------------
      // VERIFY OTP VERIFICATION IS RECENT
      // ------------------------------------------
      //
      // Allow 15 minutes after OTP verification.
      //

      const verifiedAt =
        new Date(
          user.otpVerifiedAt,
        ).getTime();

      const verificationAge =
        Date.now() -
        verifiedAt;

      const maxVerificationAge =
        15 * 60 * 1000;

      if (
        verificationAge >
        maxVerificationAge
      ) {
        return res.status(403).json({
          ok: false,
          message:
            "Your OTP verification session has expired. Please login again and request a new OTP.",
        });
      }

      // ------------------------------------------
      // HASH NEW PASSWORD
      // ------------------------------------------

      const passwordHash =
        await bcrypt.hash(
          newPassword,
          12,
        );

      // ------------------------------------------
      // UPDATE USER
      // ------------------------------------------

      const updated =
        await pool.query(
          `
          UPDATE public."app_user"
          SET
            "passwordHash" = $1,
            "mustChangePassword" = FALSE,
            "passwordChangedAt" = NOW(),
            "otpHash" = NULL,
            "otpExpiresAt" = NULL,
            "otpAttempts" = 0,
            "otpLastSentAt" = NULL,
            "otpVerifiedAt" = NULL,
            "updatedAt" = NOW()
          WHERE "id" = $2
          RETURNING
            "id",
            "employeeId",
            "username",
            "email",
            "passwordHash",
            "role",
            "isActive",
            "mustChangePassword",
            "passwordChangedAt",
            "otpVerifiedAt",
            "lastLoginAt",
            "createdAt",
            "updatedAt"
          `,
          [
            passwordHash,
            user.id,
          ],
        );

      if (
        updated.rows.length === 0
      ) {
        return res.status(500).json({
          ok: false,
          message:
            "Unable to update your password.",
        });
      }

      const updatedUser =
        updated.rows[0];

      // ------------------------------------------
      // SAFE USER
      // ------------------------------------------

      const safeUser =
        await publicAppUser(
          updatedUser,
        );

      console.log(
        "FIRST LOGIN COMPLETED:",
        {
          username:
            updatedUser.username,

          employeeId:
            updatedUser.employeeId,
        },
      );

      return res.json({
        ok: true,

        message:
          "Password created successfully. First login completed.",

        firstLogin:
          false,

        requiresOtp:
          false,

        user:
          safeUser,
      });
    } catch (error) {
      console.error(
        "SET PASSWORD ERROR:",
        error,
      );

      return res.status(500).json({
        ok: false,

        message:
          "Unable to create the new password.",

        error:
          error.message,
      });
    }
  },
);


// ============================================================
// OTP ALIASES
// ============================================================
//
// These are optional compatibility routes.
//

app.post(
  "/api/auth/request-otp",
  async (req, res) => {
    req.url =
      "/api/auth/send-otp";

    return app._router
      ? res.redirect(307, "/api/auth/send-otp")
      : res.status(500).json({
          ok: false,
          message:
            "OTP service unavailable.",
        });
  },
);
const PORT = process.env.PORT || 3000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Hasani Payroll API running on port ${PORT}`);
});
