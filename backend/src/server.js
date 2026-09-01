import "dotenv/config";

import crypto from "crypto";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import pg from "pg";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import nodemailer from "nodemailer";

import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

// ============================================================
// CONFIGURATION
// ============================================================

const PORT = Number(process.env.PORT || 5000);

const JWT_SECRET = String(
  process.env.JWT_SECRET || "",
).trim();

const JWT_EXPIRES_IN =
  process.env.JWT_EXPIRES_IN || "8h";

const FRONTEND_URL = String(process.env.FRONTEND_URL ||
    "https://hasanihub.onrender.com",
)
  .trim()
  .replace(/\/+$/, "");



const OTP_EXPIRES_MINUTES =
  Number(
    process.env.OTP_EXPIRES_MINUTES || 5,
  );

const OTP_MAX_ATTEMPTS =
  Number(
    process.env.OTP_MAX_ATTEMPTS || 5,
  );

const OTP_RESEND_SECONDS =
  Number(
    process.env.OTP_RESEND_SECONDS || 60,
  );

const OTP_VERIFICATION_MINUTES =
  Number(
    process.env.OTP_VERIFICATION_MINUTES || 15,
  );

// ============================================================
// STARTUP SECURITY CHECKS
// ============================================================

if (!JWT_SECRET) {
  console.error(
    "FATAL: JWT_SECRET is not configured.",
  );

  process.exit(1);
}

if (JWT_SECRET.length < 32) {
  console.error(
    "FATAL: JWT_SECRET must be at least 32 characters.",
  );

  process.exit(1);
}

if (
  !process.env.DATABASE_URL
) {
  console.error(
    "FATAL: DATABASE_URL is not configured.",
  );

  process.exit(1);
}

// ============================================================
// APP
// ============================================================

const app = express();

app.disable("x-powered-by");

app.set(
  "trust proxy",
  1,
);

// ============================================================
// SECURITY HEADERS
// ============================================================

app.use(
  helmet({
    contentSecurityPolicy: false,
  }),
);

// ============================================================
// CORS
// ============================================================

// ============================================================
// CORS
// ============================================================

const allowedOrigins = String(
  process.env.FRONTEND_URL ||
    "https://hasanihub.onrender.com,http://localhost:3000",
)
  .split(",")
  .map((value) => value.trim().replace(/\/+$/, ""))
  .filter(Boolean);

console.log("CORS allowed origins:", allowedOrigins);

app.use(
  cors({
    origin(origin, callback) {
      // Requests such as curl/Postman/server-to-server
      // may not contain an Origin header.
      if (!origin) {
        return callback(null, true);
      }

      const normalizedOrigin = origin
        .trim()
        .replace(/\/+$/, "");

      if (allowedOrigins.includes(normalizedOrigin)) {
        return callback(null, true);
      }

      console.error(
        "CORS BLOCKED:",
        normalizedOrigin,
      );

      console.error(
        "ALLOWED ORIGINS:",
        allowedOrigins,
      );

      return callback(
        new Error(
          `CORS origin not allowed: ${normalizedOrigin}`,
        ),
      );
    },

    credentials: true,

    methods: [
      "GET",
      "POST",
      "PUT",
      "PATCH",
      "DELETE",
      "OPTIONS",
    ],

    allowedHeaders: [
      "Content-Type",
      "Authorization",
    ],

    optionsSuccessStatus: 204,
  }),
);



// ============================================================
// BODY LIMIT
// ============================================================

app.use(
  express.json({
    limit: "2mb",
  }),
);

// ============================================================
// DATABASE
// ============================================================

const { Pool } = pg;

const pool = new Pool({
  connectionString:
    process.env.DATABASE_URL,

  max: Number(
    process.env.DB_POOL_MAX || 10,
  ),

  idleTimeoutMillis: 30000,

  connectionTimeoutMillis: 10000,
});

const adapter =
  new PrismaPg(pool);

const prisma =
  new PrismaClient({
    adapter,
  });

// ============================================================
// RATE LIMITERS
// ============================================================

const loginLimiter =
  rateLimit({
    windowMs:
      15 * 60 * 1000,

    max: 10,

    standardHeaders: true,

    legacyHeaders: false,

    skipSuccessfulRequests: true,

    message: {
      ok: false,
      message:
        "Too many login attempts. Please try again later.",
    },
  });

const otpSendLimiter =
  rateLimit({
    windowMs:
      15 * 60 * 1000,

    max: 5,

    standardHeaders: true,

    legacyHeaders: false,

    message: {
      ok: false,
      message:
        "Too many OTP requests. Please try again later.",
    },
  });

const otpVerifyLimiter =
  rateLimit({
    windowMs:
      15 * 60 * 1000,

    max: 10,

    standardHeaders: true,

    legacyHeaders: false,

    message: {
      ok: false,
      message:
        "Too many OTP verification attempts. Please try again later.",
    },
  });

const passwordLimiter =
  rateLimit({
    windowMs:
      15 * 60 * 1000,

    max: 5,

    standardHeaders: true,

    legacyHeaders: false,

    message: {
      ok: false,
      message:
        "Too many password attempts. Please try again later.",
    },
  });

// ============================================================
// HELPERS
// ============================================================

function normalizeLogin(value) {
  return String(
    value ?? "",
  )
    .trim()
    .slice(0, 200);
}

function normalizeEmployeeId(
  value,
) {
  return normalizeLogin(
    value,
  ).toUpperCase();
}

function isValidEmployeeId(
  value,
) {
  return (
    typeof value === "string" &&
    value.length >= 1 &&
    value.length <= 100 &&
    /^[A-Z0-9._-]+$/i.test(
      value,
    )
  );
}

function safeNumber(
  value,
) {
  if (
    value === null ||
    value === undefined ||
    value === ""
  ) {
    return 0;
  }

  const cleaned =
    String(value)
      .replace(/RM/gi, "")
      .replace(/,/g, "")
      .trim();

  const result =
    Number(cleaned);

  return Number.isFinite(
    result,
  )
    ? result
    : 0;
}

function genericError(
  res,
  status = 500,
) {
  return res.status(status).json({
    ok: false,
    message:
      status === 500
        ? "Internal server error."
        : "Request failed.",
  });
}

function generateOtp() {
  return crypto
    .randomInt(
      100000,
      1000000,
    )
    .toString();
}

function generateRandomToken(
  bytes = 32,
) {
  return crypto
    .randomBytes(bytes)
    .toString("hex");
}

// ============================================================
// JWT
// ============================================================

function createAccessToken(
  user,
) {
  return jwt.sign(
    {
      sub: String(user.id),

      role: String(
        user.role,
      ),

      employeeId:
        user.employeeId ||
        null,

      type: "access",
    },

    JWT_SECRET,

    {
      expiresIn:
        JWT_EXPIRES_IN,

      issuer:
        "hasani-payroll",

      audience:
        "hasani-payroll-app",
    },
  );
}

function createOtpVerificationToken(
  user,
) {
  return jwt.sign(
    {
      sub: String(user.id),

      employeeId:
        user.employeeId ||
        null,

      type:
        "otp-verification",

      nonce:
        generateRandomToken(
          16,
        ),
    },

    JWT_SECRET,

    {
      expiresIn: `${OTP_VERIFICATION_MINUTES}m`,

      issuer:
        "hasani-payroll",

      audience:
        "hasani-payroll-otp",
    },
  );
}

function verifyOtpVerificationToken(
  token,
) {
  return jwt.verify(
    token,
    JWT_SECRET,
    {
      issuer:
        "hasani-payroll",

      audience:
        "hasani-payroll-otp",
    },
  );
}

// ============================================================
// AUTHENTICATION MIDDLEWARE
// ============================================================

async function authenticate(
  req,
  res,
  next,
) {
  try {
    const header =
      req.headers.authorization ||
      "";

    if (
      !header.startsWith(
        "Bearer ",
      )
    ) {
      return res.status(401).json({
        ok: false,
        message:
          "Authentication required.",
      });
    }

    const token =
      header.slice(7).trim();

    if (!token) {
      return res.status(401).json({
        ok: false,
        message:
          "Authentication required.",
      });
    }

    const payload =
      jwt.verify(
        token,
        JWT_SECRET,
        {
          issuer:
            "hasani-payroll",

          audience:
            "hasani-payroll-app",
        },
      );

    if (
      payload.type !==
      "access"
    ) {
      return res.status(401).json({
        ok: false,
        message:
          "Invalid authentication token.",
      });
    }

    const user =
      await prisma.app_user.findUnique({
        where: {
          id: String(
            payload.sub,
          ),
        },
      });

    if (!user) {
      return res.status(401).json({
        ok: false,
        message:
          "Authentication required.",
      });
    }

    if (
      user.isActive !== true
    ) {
      return res.status(403).json({
        ok: false,
        message:
          "This account is inactive.",
      });
    }

    req.user = user;

    req.auth = payload;

    next();
  } catch {
    return res.status(401).json({
      ok: false,
      message:
        "Invalid or expired authentication token.",
    });
  }
}

// ============================================================
// ADMIN AUTHORIZATION
// ============================================================

function requireAdmin(
  req,
  res,
  next,
) {
  if (
    !req.user ||
    String(
      req.user.role,
    ).toUpperCase() !==
      "ADMIN"
  ) {
    return res.status(403).json({
      ok: false,
      message:
        "Administrator access required.",
    });
  }

  next();
}

// ============================================================
// EMPLOYEE AUTHORIZATION
// ============================================================

function requireEmployeeAccess(
  req,
  res,
  next,
) {
  const requestedId =
    normalizeEmployeeId(
      req.params.employeeId,
    );

  const authenticatedId =
    normalizeEmployeeId(
      req.user.employeeId,
    );

  const role =
    String(
      req.user.role,
    ).toUpperCase();

  // Admin can access any employee.
  if (role === "ADMIN") {
    return next();
  }

  // Employee can access only own record.
  if (
    role === "EMPLOYEE" &&
    authenticatedId &&
    requestedId ===
      authenticatedId
  ) {
    return next();
  }

  return res.status(403).json({
    ok: false,
    message:
      "You are not authorized to access this employee's payroll.",
  });
}

// ============================================================
// USER LOOKUP
// ============================================================

async function findAppUser(
  login,
) {
  const cleanLogin =
    normalizeLogin(login);

  if (!cleanLogin) {
    return null;
  }

  const employeeId =
    normalizeEmployeeId(
      cleanLogin,
    );

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

  return (
    result.rows[0] ||
    null
  );
}

// ============================================================
// SAFE USER
// ============================================================

async function publicAppUser(
  user,
) {
  const role =
    String(
      user.role ?? "",
    )
      .trim()
      .toLowerCase();

  let employee = null;

  if (user.employeeId) {
    employee =
      await prisma.employee.findUnique(
        {
          where: {
            employeeId:
              normalizeEmployeeId(
                user.employeeId,
              ),
          },
        },
      );
  }

  return {
    id: user.id ?? null,

    username:
      user.username ?? "",

    email:
      user.email ?? null,

    role,

    employeeId:
      user.employeeId ??
      null,

    displayName:
      employee?.name ??
      user.username ??
      "",

    isActive:
      user.isActive === true,

    firstLogin:
      user.mustChangePassword ===
      true,

    mustChangePassword:
      user.mustChangePassword ===
      true,

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
// PASSWORD VERIFICATION
// ============================================================

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
    String(
      storedPassword,
    ).trim();

  // SECURITY:
  // Plain-text passwords are NOT accepted.
  //
  // All passwords must be bcrypt hashes.

  if (
    !stored.startsWith(
      "$2a$",
    ) &&
    !stored.startsWith(
      "$2b$",
    ) &&
    !stored.startsWith(
      "$2y$",
    )
  ) {
    return false;
  }

  try {
    return await bcrypt.compare(
      enteredPassword,
      stored,
    );
  } catch {
    return false;
  }
}

// ============================================================
// ROOT
// ============================================================

app.get(
  "/",
  (req, res) => {
    res.json({
      name:
        "Hasani Payroll API",

      status:
        "online",

      version:
        "5.0.0-security",
    });
  },
);

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

      res.json({
        ok: true,

        database:
          "connected",

        service:
          "Hasani Payroll API",

        time:
          new Date().toISOString(),
      });
    } catch (error) {
      console.error(
        "HEALTH CHECK FAILED:",
        error.message,
      );

      res.status(503).json({
        ok: false,
        database:
          "unavailable",
        message:
          "Service temporarily unavailable.",
      });
    }
  },
);

// ============================================================
// LOGIN
// ============================================================

app.post(
  "/api/auth/login",
  loginLimiter,
  async (req, res) => {
    try {
      const username =
        normalizeLogin(
          req.body?.username,
        );

      const password =
        String(
          req.body?.password ??
            "",
        );

      if (
        !username ||
        !password
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "Username and password are required.",
        });
      }

      const user =
        await findAppUser(
          username,
        );

      // Generic response prevents account enumeration.
      if (!user) {
        return res.status(401).json({
          ok: false,
          message:
            "Invalid username or password.",
        });
      }

      if (
        user.isActive !== true
      ) {
        return res.status(401).json({
          ok: false,
          message:
            "Invalid username or password.",
        });
      }

      const matches =
        await verifyPassword(
          password,
          user.passwordHash,
        );

      if (!matches) {
        return res.status(401).json({
          ok: false,
          message:
            "Invalid username or password.",
        });
      }

      await pool.query(
        `
        UPDATE public."app_user"
        SET
          "lastLoginAt" = NOW(),
          "updatedAt" = NOW()
        WHERE "id" = $1
        `,
        [user.id],
      );

      const safeUser =
        await publicAppUser(
          user,
        );

      // First-login account.
      if (
        user.mustChangePassword ===
        true
      ) {
        return res.json({
          ok: true,

          message:
            "First login requires email verification.",

          firstLogin:
            true,

          requiresOtp:
            true,

          user:
            safeUser,
        });
      }

      const accessToken =
        createAccessToken(
          user,
        );

      return res.json({
        ok: true,

        message:
          "Login successful.",

        firstLogin:
          false,

        requiresOtp:
          false,

        accessToken,

        tokenType:
          "Bearer",

        expiresIn:
          JWT_EXPIRES_IN,

        user:
          safeUser,
      });
    } catch (error) {
      console.error(
        "LOGIN ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// CURRENT USER
// ============================================================

app.get(
  "/api/auth/me",
  authenticate,
  async (req, res) => {
    try {
      const safeUser =
        await publicAppUser(
          req.user,
        );

      res.json({
        ok: true,
        user:
          safeUser,
      });
    } catch (error) {
      console.error(
        "ME ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// COMPATIBILITY USER ROUTE
//
// IMPORTANT:
// This route is authenticated.
// It cannot be used to retrieve arbitrary users.
// ============================================================

app.get(
  "/api/auth/user/:username",
  authenticate,
  async (req, res) => {
    try {
      const requested =
        normalizeLogin(
          req.params.username,
        );

      const current =
        req.user;

      const currentUsername =
        normalizeLogin(
          current.username,
        );

      const currentEmail =
        normalizeLogin(
          current.email,
        );

      const currentEmployeeId =
        normalizeEmployeeId(
          current.employeeId,
        );

      const requestedNormalized =
        normalizeEmployeeId(
          requested,
        );

      const isOwnAccount =
        requested ===
          currentUsername ||
        requested ===
          currentEmail ||
        requestedNormalized ===
          currentEmployeeId;

      if (
        !isOwnAccount &&
        String(
          current.role,
        ).toUpperCase() !==
          "ADMIN"
      ) {
        return res.status(403).json({
          ok: false,
          message:
            "Not authorized.",
        });
      }

      const user =
        await findAppUser(
          requested,
        );

      if (!user) {
        return res.status(404).json({
          ok: false,
          message:
            "User not found.",
        });
      }

      if (
        user.isActive !== true
      ) {
        return res.status(404).json({
          ok: false,
          message:
            "User not found.",
        });
      }

      res.json({
        ok: true,

        user:
          await publicAppUser(
            user,
          ),
      });
    } catch (error) {
      console.error(
        "GET USER ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// ADMIN - EMPLOYEES
// ============================================================

app.get(
  "/api/admin/employees",
  authenticate,
  requireAdmin,
  async (req, res) => {
    try {
      const employees =
        await prisma.employee.findMany(
          {
            orderBy: {
              employeeId:
                "asc",
            },
          },
        );

      res.json({
        ok: true,

        count:
          employees.length,

        employees,
      });
    } catch (error) {
      console.error(
        "EMPLOYEE LIST ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// ADMIN - PAYROLL
// ============================================================

app.get(
  "/api/admin/payroll",
  authenticate,
  requireAdmin,
  async (req, res) => {
    try {
      const records =
        await prisma.payrollRecord.findMany(
          {
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
          },
        );

      res.json({
        ok: true,

        count:
          records.length,

        payroll:
          records,
      });
    } catch (error) {
      console.error(
        "PAYROLL LIST ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// EMPLOYEE PAYROLL
// ============================================================

app.get(
  "/api/employees/:employeeId/payroll",
  authenticate,
  requireEmployeeAccess,
  async (req, res) => {
    try {
      const employeeId =
        normalizeEmployeeId(
          req.params.employeeId,
        );

      if (
        !isValidEmployeeId(
          employeeId,
        )
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "Invalid employee ID.",
        });
      }

      const employee =
        await prisma.employee.findUnique(
          {
            where: {
              employeeId,
            },
          },
        );

      if (!employee) {
        return res.status(404).json({
          ok: false,
          message:
            "Employee not found.",
        });
      }

      const payroll =
        await prisma.payrollRecord.findMany(
          {
            where: {
              employeeId,
            },

            orderBy: {
              period:
                "desc",
            },
          },
        );

      res.json({
        ok: true,

        employee,

        count:
          payroll.length,

        payroll,
      });
    } catch (error) {
      console.error(
        "EMPLOYEE PAYROLL ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// SINGLE PAYSLIP
// ============================================================

app.get(
  "/api/employees/:employeeId/payroll/:year/:month",
  authenticate,
  requireEmployeeAccess,
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
        !isValidEmployeeId(
          employeeId,
        )
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "Invalid employee ID.",
        });
      }

      if (
        !Number.isInteger(
          year,
        ) ||
        year < 2000 ||
        year > 2100 ||
        !Number.isInteger(
          month,
        ) ||
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
        await prisma.payrollRecord.findFirst(
          {
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
          },
        );

      if (!payroll) {
        return res.status(404).json({
          ok: false,
          message:
            "Payslip not found.",
        });
      }

      res.json({
        ok: true,

        payroll,
      });
    } catch (error) {
      console.error(
        "PAYSLIP ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// ADMIN - PAYROLL IMPORT
// ============================================================

app.post(
  "/api/admin/payroll/import",
  authenticate,
  requireAdmin,
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

      // Prevent massive imports.
      if (
        rows.length > 5000
      ) {
        return res.status(413).json({
          ok: false,
          message:
            "Import is limited to 5000 rows per request.",
        });
      }

      const results = {
        total:
          rows.length,

        imported:
          0,

        updated:
          0,

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
            row.period ??
              "",
          ).trim();

        if (
          !isValidEmployeeId(
            employeeId,
          )
        ) {
          results.errors.push({
            row:
              rowNumber,

            message:
              "Invalid employee_id.",
          });

          continue;
        }

        if (
          !periodText
        ) {
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
              "Invalid payroll period.",
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
          await prisma.employee.findUnique(
            {
              where: {
                employeeId,
              },
            },
          );

        if (!employee) {
          results.errors.push({
            row:
              rowNumber,

            employeeId,

            message:
              "Employee does not exist.",
          });

          continue;
        }

        const payrollData = {
          basicSalary:
            safeNumber(
              row.basic_salary ??
                row.basicSalary,
            ),

          foodAllowance:
            safeNumber(
              row.food_allowance ??
                row.foodAllowance,
            ),

          otherAllowance:
            safeNumber(
              row.other_allowance ??
                row.otherAllowance,
            ),

          overtime:
            safeNumber(
              row.overtime,
            ),

          bonus:
            safeNumber(
              row.bonus,
            ),

          commission:
            safeNumber(
              row.commission,
            ),

          otherEarnings:
            safeNumber(
              row.other_earnings ??
                row.otherEarnings,
            ),

          epfEmployee:
            safeNumber(
              row.epf_employee ??
                row.epfEmployee,
            ),

          socsoEmployee:
            safeNumber(
              row.socso_employee ??
                row.socsoEmployee,
            ),

          eisEmployee:
            safeNumber(
              row.eis_employee ??
                row.eisEmployee,
            ),

          pcb:
            safeNumber(
              row.pcb,
            ),

          otherDeduction:
            safeNumber(
              row.other_deduction ??
                row.otherDeduction,
            ),

          epfEmployer:
            safeNumber(
              row.epf_employer ??
                row.epfEmployer,
            ),

          socsoEmployer:
            safeNumber(
              row.socso_employer ??
                row.socsoEmployer,
            ),

          eisEmployer:
            safeNumber(
              row.eis_employer ??
                row.eisEmployer,
            ),

          bankCode:
            String(
              row.bank_code ??
                row.bankCode ??
                employee.bankCode ??
                "",
            ).slice(0, 100),

          bankAccount:
            String(
              row.bank_account ??
                row.bankAccount ??
                employee.bankAccount ??
                "",
            ).slice(0, 100),

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
                ).slice(
                  0,
                  1000,
                )
              : null,
        };

        const existing =
          await prisma.payrollRecord.findUnique(
            {
              where: {
                employeeId_period:
                  {
                    employeeId,

                    period:
                      normalizedPeriod,
                  },
              },
            },
          );

        await prisma.payrollRecord.upsert(
          {
            where: {
              employeeId_period:
                {
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
          },
        );

        if (existing) {
          results.updated++;
        } else {
          results.imported++;
        }
      }

      res.json({
        ok: true,

        message:
          "Payroll import completed.",

        ...results,
      });
    } catch (error) {
      console.error(
        "PAYROLL IMPORT ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// ADMIN - DELETE PAYROLL
// ============================================================

app.delete(
  "/api/admin/payroll/:id",
  authenticate,
  requireAdmin,
  async (req, res) => {
    try {
      const id =
        String(
          req.params.id ??
            "",
        ).trim();

      if (
        !id ||
        id.length > 100
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "Invalid payroll ID.",
        });
      }

      const existing =
        await prisma.payrollRecord.findUnique(
          {
            where: {
              id,
            },
          },
        );

      if (!existing) {
        return res.status(404).json({
          ok: false,
          message:
            "Payroll record not found.",
        });
      }

      await prisma.payrollRecord.delete(
        {
          where: {
            id,
          },
        },
      );

      res.json({
        ok: true,

        message:
          "Payroll record deleted.",
      });
    } catch (error) {
      console.error(
        "DELETE PAYROLL ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// SEND OTP
// ============================================================

function createMailTransporter() {
  const smtpHost = String(
    process.env.SMTP_HOST ||
      process.env.MAIL_HOST ||
      "",
  )
    .replace(/['"\r\n]/g, "")
    .trim();

  const smtpUser = String(
    process.env.SMTP_USER ||
      process.env.MAIL_USER ||
      process.env.EMAIL_USER ||
      process.env.GMAIL_USER ||
      "",
  )
    .replace(/['"\r\n]/g, "")
    .trim();

  const smtpPassword = String(
    process.env.SMTP_PASSWORD ||
      process.env.SMTP_PASS ||
      process.env.MAIL_PASSWORD ||
      process.env.EMAIL_PASSWORD ||
      process.env.GMAIL_APP_PASSWORD ||
      process.env.GMAIL_PASSWORD ||
      "",
  )
    .replace(/['"\s\r\n]/g, "")
    .trim();

  if (!smtpUser || !smtpPassword) {
    throw new Error(
      "Email is not configured. Set SMTP_USER and SMTP_PASSWORD " +
        "(or GMAIL_USER and GMAIL_APP_PASSWORD) in Render.",
    );
  }

  // If using Gmail or no custom host specified, use Nodemailer's built-in Gmail service
  if (!smtpHost || smtpHost.toLowerCase().includes("gmail")) {
    return nodemailer.createTransport({
      service: "gmail",
      connectionTimeout: 8000,
      greetingTimeout: 8000,
      socketTimeout: 8000,
      auth: {
        user: smtpUser,
        pass: smtpPassword,
      },
    });
  }

  const smtpPort = Number(
    String(process.env.SMTP_PORT || 587).replace(/['"\r\n]/g, "").trim(),
  );

  const smtpSecure =
    String(process.env.SMTP_SECURE || "false").toLowerCase().includes("true") ||
    smtpPort === 465;

  return nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpSecure,
    connectionTimeout: 8000,
    greetingTimeout: 8000,
    socketTimeout: 8000,
    auth: {
      user: smtpUser,
      pass: smtpPassword,
    },
  });
}

async function sendOtpEmail({
  email,
  name,
  otp,
}) {
  const resendApiKey = String(process.env.RESEND_API_KEY || "")
    .replace(/['"\r\n]/g, "")
    .trim();

  const textBody = `Hello ${
    name || "User"
  },\n\nYour Hasani Payroll verification code is:\n\n${otp}\n\nThis code expires in ${OTP_EXPIRES_MINUTES} minutes.\n\nIf you did not request this code, please ignore this email.\n\nHasani Payroll`;

  const htmlBody = `
    <div style="
      font-family:Arial,sans-serif;
      max-width:600px;
      margin:auto;
      padding:20px;
    ">
      <h2>Hasani Payroll</h2>

      <p>
        Hello ${name || "User"},
      </p>

      <p>
        Your verification code is:
      </p>

      <div style="
        font-size:32px;
        font-weight:bold;
        letter-spacing:8px;
        padding:20px;
        background:#f3f4f6;
        text-align:center;
        border-radius:8px;
        margin:20px 0;
      ">
        ${otp}
      </div>

      <p>
        This code expires in
        <strong>
          ${OTP_EXPIRES_MINUTES} minutes
        </strong>.
      </p>

      <p>
        If you did not request this code,
        please ignore this email.
      </p>

      <hr>

      <p style="
        color:#6b7280;
        font-size:12px;
      ">
        Hasani Payroll
      </p>
    </div>
  `;

  // 1. If RESEND_API_KEY is configured, send via Resend HTTPS API (Port 443 - zero cloud port blocking)
  if (resendApiKey) {
    const fromAddress = String(
      process.env.RESEND_FROM ||
        process.env.SMTP_FROM ||
        "Hasani Payroll <onboarding@resend.dev>",
    )
      .replace(/['"\r\n]/g, "")
      .trim();

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromAddress,
        to: [email],
        subject: "Hasani Payroll - Verification Code",
        text: textBody,
        html: htmlBody,
      }),
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(
        data.message || `Resend API error (${response.status})`,
      );
    }
    return;
  }

  // 2. Otherwise send via Nodemailer (Gmail or Custom SMTP)
  const transporter = createMailTransporter();

  const rawFrom = String(
    process.env.SMTP_FROM ||
      process.env.MAIL_FROM ||
      process.env.EMAIL_FROM ||
      "",
  )
    .replace(/['"\r\n]/g, "")
    .trim();

  const smtpUser = String(
    process.env.SMTP_USER ||
      process.env.MAIL_USER ||
      process.env.EMAIL_USER ||
      process.env.GMAIL_USER ||
      "",
  )
    .replace(/['"\r\n]/g, "")
    .trim();

  const from =
    rawFrom ||
    (smtpUser ? `Hasani Payroll <${smtpUser}>` : "Hasani Payroll");

  await transporter.sendMail(
    {
      from,
      to: email,
      subject: "Hasani Payroll - Verification Code",
      text: textBody,
      html: htmlBody,
    },
  );
}

app.post(
  "/api/auth/send-otp",
  otpSendLimiter,
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

      const user =
        await findAppUser(
          loginValue,
        );

      // Do not reveal whether an account exists.
      if (
        !user ||
        user.isActive !==
          true ||
        user.mustChangePassword !==
          true
      ) {
        return res.json({
          ok: true,

          message:
            "If the account is eligible, a verification code has been sent.",
        });
      }

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
            "The account does not have a registered email address.",
        });
      }

      // Database resend protection.
      if (
        user.otpLastSentAt
      ) {
        const lastSent =
          new Date(
            user.otpLastSentAt,
          ).getTime();

        const elapsed =
          Date.now() -
          lastSent;

        if (
          elapsed <
          OTP_RESEND_SECONDS *
            1000
        ) {
          const remaining =
            Math.ceil(
              (
                OTP_RESEND_SECONDS *
                  1000 -
                elapsed
              ) / 1000,
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

      const otp =
        generateOtp();

      const otpHash =
        await bcrypt.hash(
          otp,
          12,
        );

      const expiresAt =
        new Date(
          Date.now() +
            OTP_EXPIRES_MINUTES *
              60 *
              1000,
        );

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

      try {
        await sendOtpEmail(
          {
            email,

            name:
              user.username ||
              "User",

            otp,
          },
        );
      } catch (emailError) {
        console.error(
          "OTP EMAIL ERROR:",
          emailError.message,
        );

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
          [user.id],
        );

        return res.status(500).json({
          ok: false,
          message:
            "Unable to send verification code.",
        });
      }

      // Signed token instead of exposing database ID
      // as the OTP session identifier.
      const otpId =
        jwt.sign(
          {
            sub:
              String(
                user.id,
              ),

            type:
              "otp-session",

            nonce:
              generateRandomToken(
                16,
              ),
          },

          JWT_SECRET,

          {
            expiresIn:
              `${OTP_EXPIRES_MINUTES}m`,

            issuer:
              "hasani-payroll",

            audience:
              "hasani-payroll-otp",
          },
        );

      return res.json({
        ok: true,

        message:
          "Verification code sent to your registered email address.",

        otpId,

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
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// VERIFY OTP
// ============================================================

app.post(
  "/api/auth/verify-otp",
  otpVerifyLimiter,
  async (req, res) => {
    try {
      const otp =
        String(
          req.body?.otp ??
            "",
        ).trim();

      const otpId =
        String(
          req.body?.otpId ??
            "",
        ).trim();

      if (
        !/^\d{6}$/.test(
          otp,
        )
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "OTP must be a 6-digit code.",
        });
      }

      if (
        !otpId ||
        otpId.length > 2000
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "OTP session is required.",
        });
      }

      let session;

      try {
        session =
          jwt.verify(
            otpId,
            JWT_SECRET,
            {
              issuer:
                "hasani-payroll",

              audience:
                "hasani-payroll-otp",
            },
          );
      } catch {
        return res.status(401).json({
          ok: false,
          message:
            "OTP session has expired. Please request a new OTP.",
        });
      }

      if (
        session.type !==
        "otp-session"
      ) {
        return res.status(401).json({
          ok: false,
          message:
            "Invalid OTP session.",
        });
      }

      const user =
        await prisma.app_user.findUnique(
          {
            where: {
              id: String(
                session.sub,
              ),
            },
          },
        );

      if (
        !user ||
        user.isActive !==
          true
      ) {
        return res.status(401).json({
          ok: false,
          message:
            "Invalid OTP session.",
        });
      }

      if (
        user.mustChangePassword !==
        true
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "First-login verification is not required.",
        });
      }

      if (
        !user.otpHash ||
        !user.otpExpiresAt
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "No active OTP. Please request a new code.",
        });
      }

      if (
        new Date(
          user.otpExpiresAt,
        ).getTime() <=
        Date.now()
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "OTP has expired. Please request a new code.",
        });
      }

      const attempts =
        Number(
          user.otpAttempts ||
            0,
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
              COALESCE(
                "otpAttempts",
                0
              ) + 1,
            "updatedAt" = NOW()
          WHERE "id" = $1
          `,
          [user.id],
        );

        return res.status(401).json({
          ok: false,
          message:
            "Invalid OTP.",
          attemptsRemaining:
            Math.max(
              0,
              OTP_MAX_ATTEMPTS -
                attempts -
                1,
            ),
        });
      }

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
        [user.id],
      );

      const verificationToken =
        createOtpVerificationToken(
          user,
        );

      return res.json({
        ok: true,

        verified:
          true,

        message:
          "OTP verified successfully.",

        verificationId:
          verificationToken,

        employeeId:
          user.employeeId,

        username:
          user.username,
      });
    } catch (error) {
      console.error(
        "VERIFY OTP ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// SET PASSWORD AFTER OTP
// ============================================================

app.post(
  "/api/auth/set-password",
  passwordLimiter,
  async (req, res) => {
    try {
      const verificationId =
        String(
          req.body?.verificationId ??
            "",
        ).trim();

      const newPassword =
        String(
          req.body?.newPassword ??
            "",
        );

      if (
        !verificationId
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "Verification session is required.",
        });
      }

      if (
        newPassword.length <
          8 ||
        newPassword.length >
          128
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "Password must contain between 8 and 128 characters.",
        });
      }

      let session;

      try {
        session =
          verifyOtpVerificationToken(
            verificationId,
          );
      } catch {
        return res.status(403).json({
          ok: false,
          message:
            "Verification session has expired. Please verify your OTP again.",
        });
      }

      if (
        session.type !==
        "otp-verification"
      ) {
        return res.status(403).json({
          ok: false,
          message:
            "Invalid verification session.",
        });
      }

      const user =
        await prisma.app_user.findUnique(
          {
            where: {
              id: String(
                session.sub,
              ),
            },
          },
        );

      if (
        !user ||
        user.isActive !==
          true
      ) {
        return res.status(403).json({
          ok: false,
          message:
            "Invalid verification session.",
        });
      }

      if (
        user.mustChangePassword !==
        true
      ) {
        return res.status(400).json({
          ok: false,
          message:
            "Password setup is not required.",
        });
      }

      if (
        !user.otpVerifiedAt
      ) {
        return res.status(403).json({
          ok: false,
          message:
            "OTP verification is required.",
        });
      }

      const verifiedAt =
        new Date(
          user.otpVerifiedAt,
        ).getTime();

      if (
        Date.now() -
          verifiedAt >
        OTP_VERIFICATION_MINUTES *
          60 *
          1000
      ) {
        return res.status(403).json({
          ok: false,
          message:
            "Verification session has expired. Please verify OTP again.",
        });
      }

      const passwordHash =
        await bcrypt.hash(
          newPassword,
          12,
        );

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
            "role",
            "isActive",
            "mustChangePassword",
            "passwordChangedAt",
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
        updated.rows.length ===
        0
      ) {
        return res.status(500).json({
          ok: false,
          message:
            "Unable to create password.",
        });
      }

      const updatedUser =
        updated.rows[0];

      const safeUser =
        await publicAppUser(
          updatedUser,
        );

      const accessToken =
        createAccessToken(
          updatedUser,
        );

      return res.json({
        ok: true,

        message:
          "Password created successfully.",

        firstLogin:
          false,

        requiresOtp:
          false,

        accessToken,

        tokenType:
          "Bearer",

        expiresIn:
          JWT_EXPIRES_IN,

        user:
          safeUser,
      });
    } catch (error) {
      console.error(
        "SET PASSWORD ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// OTP COMPATIBILITY ALIAS
// ============================================================

app.post(
  "/api/auth/request-otp",
  otpSendLimiter,
  async (req, res) => {
    // Keep compatibility with existing Flutter code.
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

      const user =
        await findAppUser(
          loginValue,
        );

      if (
        !user ||
        user.isActive !==
          true ||
        user.mustChangePassword !==
          true
      ) {
        return res.json({
          ok: true,
          message:
            "If the account is eligible, a verification code has been sent.",
        });
      }

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
            "The account does not have a registered email address.",
        });
      }

      if (
        user.otpLastSentAt
      ) {
        const elapsed =
          Date.now() -
          new Date(
            user.otpLastSentAt,
          ).getTime();

        if (
          elapsed <
          OTP_RESEND_SECONDS *
            1000
        ) {
          const remaining =
            Math.ceil(
              (
                OTP_RESEND_SECONDS *
                  1000 -
                elapsed
              ) / 1000,
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

      const otp =
        generateOtp();

      const otpHash =
        await bcrypt.hash(
          otp,
          12,
        );

      const expiresAt =
        new Date(
          Date.now() +
            OTP_EXPIRES_MINUTES *
              60 *
              1000,
        );

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

      await sendOtpEmail({
        email,

        name:
          user.username ||
          "User",

        otp,
      });

      const otpId =
        jwt.sign(
          {
            sub:
              String(
                user.id,
              ),

            type:
              "otp-session",

            nonce:
              generateRandomToken(
                16,
              ),
          },

          JWT_SECRET,

          {
            expiresIn:
              `${OTP_EXPIRES_MINUTES}m`,

            issuer:
              "hasani-payroll",

            audience:
              "hasani-payroll-otp",
          },
        );

      return res.json({
        ok: true,

        message:
          "Verification code sent.",

        otpId,

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
        "REQUEST OTP ERROR:",
        error.message,
      );

      return genericError(
        res,
      );
    }
  },
);

// ============================================================
// 404
// ============================================================

app.use(
  (req, res) => {
    res.status(404).json({
      ok: false,
      message:
        "Endpoint not found.",
    });
  },
);

// ============================================================
// ERROR HANDLER
// ============================================================

app.use(
  (
    error,
    req,
    res,
    next,
  ) => {
    console.error(
      "UNHANDLED API ERROR:",
      error.message,
    );

    if (
      res.headersSent
    ) {
      return next(error);
    }

    res.status(500).json({
      ok: false,
      message:
        "Internal server error.",
    });
  },
);

// ============================================================
// DATABASE TEST
// ============================================================

async function testDatabase() {
  try {
    await pool.query(
      "SELECT 1",
    );

    console.log(
      "DATABASE: connected",
    );
  } catch (error) {
    console.error(
      "DATABASE CONNECTION FAILED:",
      error.message,
    );

    process.exit(1);
  }
}

// ============================================================
// SERVER
// ============================================================

let server;

async function startServer() {
  await testDatabase();

  server =
    app.listen(
      PORT,
      "0.0.0.0",
      () => {
        console.log(
          "========================================",
        );

        console.log(
          "HASANI PAYROLL API",
        );

        console.log(
          `PORT: ${PORT}`,
        );

        console.log(
          "SECURITY: ENABLED",
        );

        console.log(
          "JWT AUTH: ENABLED",
        );

        console.log(
          "RBAC: ENABLED",
        );

        console.log(
          "OTP: ENABLED",
        );

        console.log(
          "========================================",
        );
      },
    );
}

startServer().catch(
  (error) => {
    console.error(
      "SERVER STARTUP FAILED:",
      error.message,
    );

    process.exit(1);
  },
);

// ============================================================
// GRACEFUL SHUTDOWN
// ============================================================

async function shutdown(
  signal,
) {
  console.log(
    `${signal}: shutting down...`,
  );

  if (server) {
    server.close(
      async () => {
        try {
          await prisma.$disconnect();

          await pool.end();

          console.log(
            "Shutdown complete.",
          );

          process.exit(0);
        } catch (error) {
          console.error(
            "Shutdown error:",
            error.message,
          );

          process.exit(1);
        }
      },
    );
  } else {
    await prisma.$disconnect();

    await pool.end();

    process.exit(0);
  }
}

process.on(
  "SIGINT",
  () =>
    shutdown("SIGINT"),
);

process.on(
  "SIGTERM",
  () =>
    shutdown("SIGTERM"),

);

