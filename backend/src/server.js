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
import {
  ensureAdminAccount,
  ensureFrnBranchAccounts,
  ensurePlayReviewerAccount,
} from "./startup-accounts.js";

import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import {
  findActiveEmployeeIdentity,
  findPasswordResetUser,
  normalizeIdentityNumber,
  resolvePasswordRecoveryEmployeeId,
} from "./identity.js";

// ============================================================
// CONFIGURATION
// ============================================================

const PORT = Number(process.env.PORT || 5000);

const JWT_SECRET = String(
  process.env.JWT_SECRET || "",
).trim();

const ACCESS_TOKEN_SECRET = JWT_SECRET;

const DATA_API_JWT_PRIVATE_KEY = String(
  process.env.DATA_API_JWT_PRIVATE_KEY || "",
).replace(/\\n/g, "\n").trim();

const DATA_API_JWT_KEY_ID = String(
  process.env.DATA_API_JWT_KEY_ID || "hasani-neon-data-api",
).trim();

const DATA_API_JWT_ISSUER = String(
  process.env.DATA_API_JWT_ISSUER || "https://hasaniworkhub.onrender.com",
).trim().replace(/\/+$/, "");

let dataApiJwtPrivateKey = null;
let dataApiJwtPublicJwk = null;

if (DATA_API_JWT_PRIVATE_KEY) {
  try {
    dataApiJwtPrivateKey = crypto.createPrivateKey(DATA_API_JWT_PRIVATE_KEY);
    const publicKey = crypto.createPublicKey(dataApiJwtPrivateKey);
    dataApiJwtPublicJwk = {
      ...publicKey.export({ format: "jwk" }),
      alg: "RS256",
      use: "sig",
      kid: DATA_API_JWT_KEY_ID,
    };
  } catch (error) {
    console.error("FATAL: DATA_API_JWT_PRIVATE_KEY is invalid.", error.message);
    process.exit(1);
  }
}

const JWT_EXPIRES_IN =
  process.env.JWT_EXPIRES_IN || "8h";

const PLAY_REVIEWER_USERNAME = String(
  process.env.PLAY_REVIEWER_USERNAME || "googleplayreviewer",
).trim().toLowerCase();
const PLAY_REVIEWER_EMAIL = String(
  process.env.PLAY_REVIEWER_EMAIL || "googleplayreviewer@hasani.local",
).trim().toLowerCase();
const PLAY_REVIEWER_PASSWORD = String(
  process.env.PLAY_REVIEWER_PASSWORD || "",
);
const PLAY_REVIEWER_EMPLOYEE_ID = "PLAY_REVIEWER";

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

app.use(helmet());

// ============================================================
// CORS
// ============================================================

// ============================================================
// CORS
// ============================================================

const allowedOrigins = (
  String(
    process.env.FRONTEND_URL ||
      "https://hasanihub.onrender.com,http://localhost:3000",
  )
    .split(",")
    .map((value) => value.trim().replace(/\/+$/, ""))
    .filter(Boolean)
    // Also add backend URL for health checks
    .concat([
      "https://hasaniworkhub.onrender.com",
      "https://hasaniworkhub.onrender.com:5000",
      "http://localhost:5000",
      "http://localhost:3001",
      "http://127.0.0.1:3001",
    ])
);

// Remove duplicates
const uniqueOrigins = [...new Set(allowedOrigins)];

console.log("✅ CORS allowed origins:", uniqueOrigins);

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
        .toLowerCase()
        .replace(/\/+$/, "");

      const originAllowed = uniqueOrigins.some(
        (allowed) => allowed.toLowerCase() === normalizedOrigin,
      );

      if (originAllowed) {
        return callback(null, true);
      }

      console.warn(
        "⚠️  CORS blocked:",
        normalizedOrigin,
      );

      console.warn(
        "Allowed origins:",
        uniqueOrigins,
      );

      return callback(new Error('Origin not allowed by CORS.'));
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

    optionsSuccessStatus: 200,
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

function isPlayReviewer(user) {
  const username = String(user?.username || "").trim().toLowerCase();
  const email = String(user?.email || "").trim().toLowerCase();
  const employeeId = normalizeEmployeeId(user?.employeeId);
  return employeeId === PLAY_REVIEWER_EMPLOYEE_ID ||
    username === PLAY_REVIEWER_USERNAME || email === PLAY_REVIEWER_EMAIL;
}
function createAccessToken(
  user,
  staffScope = null,
) {
  const login = String(user.username || user.email || "").trim().toUpperCase();
  const baseLogin = login.endsWith("FRN") ? login.slice(0, -3) : login;
  const branchByLogin = {
    HBSP: "SUNGAI PETANI", HPSP: "SUNGAI PETANI", HBAMJ: "AMANJAYA",
    HBAS: "ALOR SETAR", HBASTANA: "ASTANA", HBGURUN: "GURUN",
    HBJITRA: "JITRA", HBPERAI: "PRAI", HBKULIM: "KULIM", HBLKW: "LANGKAWI",
  };
  const appRole = staffScope === "requests"
    ? "request_admin"
    : String(user.role || "employee").trim().toLowerCase();
  const branchId = branchByLogin[baseLogin] || null;
  return jwt.sign(
    {
      sub: String(user.id ?? user.username ?? user.email),

      role: "authenticated",
      app_metadata: {
        app_role: appRole,
        branch_id: branchId,
        employee_id: user.employeeId || null,
        is_frn: login.endsWith("FRN"),
        is_reviewer: isPlayReviewer(user),
        staff_scope: staffScope,
      },

      employeeId:
        user.employeeId ||
        null,

      type: "access",
    },

    ACCESS_TOKEN_SECRET,

    {
      expiresIn:
        JWT_EXPIRES_IN,

      issuer:
        "hasani-payroll",

      audience:
        "authenticated",
    },
  );
}

function createDataApiAccessToken(
  user,
  staffScope = null,
) {
  if (!dataApiJwtPrivateKey) return null;

  const login = String(user.username || user.email || "").trim().toUpperCase();
  const baseLogin = login.endsWith("FRN") ? login.slice(0, -3) : login;
  const branchByLogin = {
    HBSP: "SUNGAI PETANI", HPSP: "SUNGAI PETANI", HBAMJ: "AMANJAYA",
    HBAS: "ALOR SETAR", HBASTANA: "ASTANA", HBGURUN: "GURUN",
    HBJITRA: "JITRA", HBPERAI: "PRAI", HBKULIM: "KULIM", HBLKW: "LANGKAWI",
  };
  const appRole = staffScope === "requests"
    ? "request_admin"
    : String(user.role || "employee").trim().toLowerCase();

  return jwt.sign(
    {
      sub: String(user.id ?? user.username ?? user.email),
      role: "authenticated",
      app_metadata: {
        app_role: appRole,
        branch_id: branchByLogin[baseLogin] || null,
        employee_id: user.employeeId || null,
        is_frn: login.endsWith("FRN"),
        is_reviewer: isPlayReviewer(user),
        staff_scope: staffScope,
      },
      employeeId: user.employeeId || null,
      type: "data-access",
    },
    dataApiJwtPrivateKey,
    {
      algorithm: "RS256",
      keyid: DATA_API_JWT_KEY_ID,
      expiresIn: JWT_EXPIRES_IN,
      issuer: DATA_API_JWT_ISSUER,
      audience: "authenticated",
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

function createFirstLoginPasswordToken(
  user,
) {
  return jwt.sign(
    {
      sub: String(user.id),
      employeeId: user.employeeId || null,
      type: "first-login-password",
      nonce: generateRandomToken(16),
    },
    JWT_SECRET,
    {
      expiresIn: String(OTP_VERIFICATION_MINUTES) + "m",
      issuer: "hasani-payroll",
      audience: "hasani-payroll-otp",
    },
  );
}

function createPasswordResetToken(user) {
  return jwt.sign(
    {
      sub: String(user.id),
      type: "password-reset",
      passwordVersion: user.passwordChangedAt
        ? new Date(user.passwordChangedAt).toISOString()
        : null,
      nonce: generateRandomToken(16),
    },
    JWT_SECRET,
    {
      expiresIn: "10m",
      issuer: "hasani-payroll",
      audience: "hasani-payroll-password-reset",
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
        ACCESS_TOKEN_SECRET,
        {
          issuer:
            "hasani-payroll",

          audience:
            "authenticated",
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

    // Neon app_user uses username as its primary key (not a synthetic id).
    // Resolve the token subject against the supported identity columns without
    // relying on the legacy Prisma app_user model.
    const userResult = await pool.query(
      `SELECT to_jsonb(u) AS data
       FROM public.app_user AS u
       WHERE COALESCE(to_jsonb(u)->>'username', '') = $1
          OR COALESCE(to_jsonb(u)->>'email', '') = $1
          OR COALESCE(to_jsonb(u)->>'id', '') = $1
          OR COALESCE(to_jsonb(u)->>'employee_id', to_jsonb(u)->>'employeeId', '') = $1
       LIMIT 1`,
      [String(payload.sub)],
    );
    const rawUser = userResult.rows[0]?.data;
    const user = rawUser ? {
      ...rawUser,
      id: rawUser.id ?? rawUser.username ?? rawUser.email ?? rawUser.employee_id ?? rawUser.employeeId,
      username: rawUser.username ?? rawUser.email ?? rawUser.employee_id ?? rawUser.employeeId ?? '',
      employeeId: rawUser.employeeId ?? rawUser.employee_id ?? null,
      passwordHash: rawUser.passwordHash ?? rawUser.passwordhash ?? rawUser.password_hash ?? null,
      isActive: [true, "true", "t", "1"].includes(rawUser.isActive ?? rawUser.is_active ?? true),
      mustChangePassword: rawUser.mustChangePassword ?? rawUser.must_change_password ?? false,
      passwordChangedAt: rawUser.passwordChangedAt ?? rawUser.password_changed_at ?? null,
    } : null;

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

async function findAppUser(login) {
  const cleanLogin = normalizeLogin(login);
  if (!cleanLogin) return null;

  const employeeId = normalizeEmployeeId(cleanLogin);
  // Read the row as JSON so older deployments that do not yet contain every
  // optional auth/OTP column still support login and password recovery.
  const result = await pool.query(
    `SELECT to_jsonb(account_row) AS data
     FROM public."app_user" AS account_row
     WHERE LOWER(TRIM(COALESCE(
             to_jsonb(account_row) ->> 'username',
             ''
           ))) = LOWER(TRIM($1))
        OR LOWER(TRIM(COALESCE(
             to_jsonb(account_row) ->> 'email',
             ''
           ))) = LOWER(TRIM($1))
        OR UPPER(TRIM(COALESCE(
             to_jsonb(account_row) ->> 'employeeId',
             to_jsonb(account_row) ->> 'employee_id',
             ''
           ))) = $2
     LIMIT 1`,
    [cleanLogin, employeeId],
  );

  const data = result.rows[0]?.data;
  if (!data) return null;
  return {
    ...data,
    employeeId: data.employeeId ?? data.employee_id ?? null,
    passwordHash:
      data.passwordHash ??
      data.passwordhash ??
      data.password_hash ??
      data.password ??
      null,
    isActive: [true, "true", "t", "1"].includes(
      data.isActive ?? data.is_active ?? true,
    ),
    mustChangePassword:
      data.mustChangePassword ?? data.must_change_password ?? false,
    passwordChangedAt:
      data.passwordChangedAt ?? data.password_changed_at ?? null,
  };
}

async function findPrimaryAdminUser() {
  const result = await pool.query(
    `SELECT to_jsonb(account_row) AS data
     FROM public."app_user" AS account_row
     WHERE UPPER(TRIM(COALESCE(to_jsonb(account_row) ->> 'role', ''))) = 'ADMIN'
       AND COALESCE((to_jsonb(account_row) ->> 'isActive')::boolean, true) = true
     ORDER BY
       CASE
         WHEN LOWER(TRIM(COALESCE(to_jsonb(account_row) ->> 'username', ''))) = 'admin' THEN 0
         WHEN LOWER(TRIM(COALESCE(to_jsonb(account_row) ->> 'email', ''))) = 'admin@hasani.local' THEN 1
         ELSE 2
       END,
       COALESCE(to_jsonb(account_row) ->> 'createdAt', '')
     LIMIT 1`,
  );
  const data = result.rows[0]?.data;
  if (!data) return null;
  return {
    ...data,
    employeeId: data.employeeId ?? data.employee_id ?? null,
    passwordHash:
      data.passwordHash ??
      data.passwordhash ??
      data.password_hash ??
      data.password ??
      null,
    isActive: [true, "true", "t", "1"].includes(
      data.isActive ?? data.is_active ?? true,
    ),
    mustChangePassword:
      data.mustChangePassword ?? data.must_change_password ?? false,
  };
}

// ============================================================
// SAFE USER
// ============================================================

async function publicAppUser(
  user,
  staffScope = null,
  loginAlias = null,
) {
  const role = String(user.role ?? "").trim().toLowerCase();
  const reviewer = isPlayReviewer(user);
  let employee = null;

  if (user.employeeId && !reviewer) {
    try {
      const result = await pool.query(
        `SELECT to_jsonb(e) AS data
         FROM public.employees AS e
         WHERE UPPER(TRIM(e.employee_id)) = $1
         LIMIT 1`,
        [normalizeEmployeeId(user.employeeId)],
      );
      employee = result.rows[0]?.data ?? null;
    } catch (error) {
      console.warn("PUBLIC USER EMPLOYEE LOOKUP FAILED:", error.message);
    }
  }

  return {
    id: user.id ?? user.username ?? user.email ?? null,
    username: loginAlias ?? user.username ?? user.email ?? "",
    email: user.email ?? null,
    role,
    employeeId: user.employeeId ?? user.employee_id ?? null,
    branchId: role === "branch"
      ? (user.branchId ?? user.branch_id ?? normalizeLogin(user.username || user.email))
      : (employee?.branch_id ?? employee?.branch ?? user.branchId ?? user.branch_id ?? null),
    displayName: employee?.name ?? user.displayName ?? user.display_name ?? user.username ?? "",
    isActive: user.isActive === true,
    firstLogin: user.mustChangePassword === true || user.must_change_password === true,
    mustChangePassword: user.mustChangePassword === true || user.must_change_password === true,
    employee,
    isAdmin: role === "admin",
    isBranch: role === "branch",
    isEmployee: role === "employee",
    isReviewer: reviewer,
    staffScope,
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

// Public verification keys used by the Neon Data API. The private signing key
// never leaves the backend environment.
app.get("/.well-known/jwks.json", (req, res) => {
  res.set("Cache-Control", "public, max-age=300");
  res.json({
    keys: dataApiJwtPublicJwk ? [dataApiJwtPublicJwk] : [],
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

      const normalizedUsername = username.toLowerCase();
      const scopedAdminLogin = normalizedUsername === "adminloc" || normalizedUsername === "adminfrn";
      const requestAdminLogin = normalizedUsername === "hbreq";
      const attendanceAdminLogin = normalizedUsername === "account";
      const staffScope = normalizedUsername === "adminloc"
        ? "local"
        : normalizedUsername === "adminfrn"
          ? "foreign"
          : requestAdminLogin
            ? "requests"
            : attendanceAdminLogin
              ? "attendance"
              : null;

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

      const configuredAdminPassword = String(process.env.ADMIN_PASSWORD || "");
      const user = requestAdminLogin
        ? (configuredAdminPassword.length > 0
            ? {
                id: "hbreq",
                username: "hbreq",
                email: null,
                role: "ADMIN",
                isActive: true,
                mustChangePassword: false,
                employeeId: null,
              }
            : null)
        : scopedAdminLogin
          ? await findPrimaryAdminUser()
          : await findAppUser(username);

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

      const matches = requestAdminLogin
        ? matchesConfiguredPassword(password, configuredAdminPassword)
        : await verifyPassword(password, user.passwordHash);

      if (!matches) {
        return res.status(401).json({
          ok: false,
          message:
            "Invalid username or password.",
        });
      }

      const safeUser =
        await publicAppUser(
          user,
          staffScope,
          scopedAdminLogin ? normalizedUsername : null,
        );

      // The default password was verified. Issue a short-lived, restricted
      // token that can only complete the mandatory first-login password change.
      if (
        user.mustChangePassword ===
        true
      ) {
        const verificationId =
          createFirstLoginPasswordToken(
            user,
          );

        return res.json({
          ok: true,

          message:
            "You must create a new password before opening the dashboard.",

          firstLogin:
            true,

          requiresOtp:
            false,

          requiresPasswordChange:
            true,

          verificationId,

          user:
            safeUser,
        });
      }

      const accessToken =
        createAccessToken(
          user,
          staffScope,
        );
      const dataAccessToken =
        createDataApiAccessToken(
          user,
          staffScope,
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

        ...(dataAccessToken ? { dataAccessToken } : {}),

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
// CHANGE PASSWORD (AUTHENTICATED)
// ============================================================

app.post(
  "/api/auth/change-password",
  passwordLimiter,
  authenticate,
  async (req, res) => {
    try {
      const currentPassword = String(req.body?.currentPassword ?? "");
      const newPassword = String(req.body?.newPassword ?? "");

      if (newPassword.length < 8 || newPassword.length > 128) {
        return res.status(400).json({
          ok: false,
          message: "Password must contain between 8 and 128 characters.",
        });
      }

      if (currentPassword === newPassword) {
        return res.status(400).json({
          ok: false,
          message: "New password must be different.",
        });
      }

      const matches = await verifyPassword(
        currentPassword,
        req.user.passwordHash,
      );

      if (!matches) {
        return res.status(401).json({
          ok: false,
          message: "Current password is incorrect.",
        });
      }

      const passwordHash = await bcrypt.hash(newPassword, 12);
      await pool.query(
        `UPDATE public."app_user"
         SET "passwordHash" = $1,
             "passwordChangedAt" = NOW(),
             "updatedAt" = NOW()
         WHERE "username" = $2 OR "email" = $2 OR "employee_id" = $2`,
        [passwordHash, req.user.username ?? req.user.email ?? req.user.employeeId],
      );

      return res.json({ok: true, message: "Password updated successfully."});
    } catch (error) {
      console.error("CHANGE PASSWORD ERROR:", error.message);
      return genericError(res);
    }
  },
);

// ============================================================
// FORGOT PASSWORD
// ============================================================

app.post(
  "/api/auth/forgot-password/verify",
  passwordLimiter,
  async (req, res) => {
    try {
      const username = normalizeLogin(req.body?.username);
      const identityNumber = normalizeIdentityNumber(req.body?.identityNumber);

      if (!username || !identityNumber) {
        return res.status(400).json({
          ok: false,
          message: "Username and IC number are required.",
        });
      }

      const user = await findAppUser(username);
      let identityMatches = false;

      const recoveryEmployeeId = resolvePasswordRecoveryEmployeeId(
        user,
        username,
      );

      if (user?.isActive === true && recoveryEmployeeId) {
        // Employee profile data is stored in the Supabase-style `employees`
        // table. Do not use Prisma's legacy `Employee` model here: it maps to
        // a different table and includes identity columns that do not exist in
        // the current schema.
        let employeeIdentity;
        try {
          employeeIdentity = await findActiveEmployeeIdentity(
            pool,
            recoveryEmployeeId,
          );
        } catch (identityError) {
          // Support installations still using Prisma's legacy Employee table
          // while the Supabase employees migration is being applied.
          console.warn("PRIMARY EMPLOYEE IDENTITY LOOKUP FAILED:", identityError.message);
          const legacyEmployee = await prisma.employee.findUnique({
            where: { employeeId: normalizeEmployeeId(recoveryEmployeeId) },
            select: { newIcNo: true, isActive: true },
          });
          employeeIdentity = legacyEmployee?.isActive
            ? legacyEmployee.newIcNo
            : null;
        }
        identityMatches = Boolean(
          employeeIdentity &&
            normalizeIdentityNumber(employeeIdentity) === identityNumber,
        );
      }

      // Keep this response generic so an attacker cannot discover accounts or IDs.
      if (!user || !identityMatches) {
        return res.status(401).json({
          ok: false,
          message: "The username and IC number do not match.",
        });
      }

      return res.json({
        ok: true,
        message: "Identity verified.",
        resetToken: createPasswordResetToken(user),
        expiresIn: 600,
      });
    } catch (error) {
      console.error("FORGOT PASSWORD VERIFY ERROR:", error.message);
      return genericError(res);
    }
  },
);

app.post(
  "/api/auth/forgot-password/reset",
  passwordLimiter,
  async (req, res) => {
    try {
      const resetToken = String(req.body?.resetToken ?? "");
      const newPassword = String(req.body?.newPassword ?? "");

      if (newPassword.length < 8 || newPassword.length > 128) {
        return res.status(400).json({
          ok: false,
          message: "Password must contain between 8 and 128 characters.",
        });
      }

      let payload;
      try {
        payload = jwt.verify(resetToken, JWT_SECRET, {
          issuer: "hasani-payroll",
          audience: "hasani-payroll-password-reset",
        });
      } catch {
        return res.status(401).json({
          ok: false,
          message: "The password reset session is invalid or has expired.",
        });
      }

      if (payload.type !== "password-reset") {
        return res.status(401).json({ ok: false, message: "Invalid password reset session." });
      }

      // Keep password recovery compatible with app_user deployments that do
      // not yet contain every optional column represented by the Prisma model.
      const user = await findPasswordResetUser(pool, payload.sub);
      const currentVersion = user?.passwordChangedAt
        ? new Date(user.passwordChangedAt).toISOString()
        : null;
      if (!user || user.isActive !== true || payload.passwordVersion !== currentVersion) {
        return res.status(401).json({
          ok: false,
          message: "The password reset session is invalid or has already been used.",
        });
      }

      if (await verifyPassword(newPassword, user.passwordHash)) {
        return res.status(400).json({ ok: false, message: "New password must be different." });
      }

      const passwordHash = await bcrypt.hash(newPassword, 12);
      await pool.query(
        `UPDATE public."app_user"
         SET "passwordHash" = $1, "mustChangePassword" = FALSE,
             "passwordChangedAt" = NOW(), "updatedAt" = NOW()
         WHERE "id" = $2`,
        [passwordHash, user.id],
      );

      return res.json({ ok: true, message: "Password reset successfully. You can now sign in." });
    } catch (error) {
      console.error("FORGOT PASSWORD RESET ERROR:", error.message);
      return genericError(res);
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
          req.auth?.app_metadata?.staff_scope ?? null,
          req.auth?.app_metadata?.staff_scope === "local"
            ? "adminloc"
            : req.auth?.app_metadata?.staff_scope === "foreign"
              ? "adminfrn"
              : null,
        );

      const dataAccessToken = createDataApiAccessToken(
        req.user,
        req.auth?.app_metadata?.staff_scope ?? null,
      );
      res.set("Cache-Control", "no-store");
      res.json({
        ok: true,
        ...(dataAccessToken ? { dataAccessToken } : {}),
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
      const result = await pool.query(
        `SELECT to_jsonb(e) AS data
         FROM public.employees AS e
         ORDER BY e.employee_id ASC`,
      );
      const employees = result.rows.map((row) => row.data);
      return res.json({ ok: true, count: employees.length, employees });
    } catch (error) {
      console.error("EMPLOYEE LIST ERROR:", error.message);
      return genericError(res, 503);
    }
  },
);

// ============================================================
app.post(
  "/api/admin/employees/:employeeId/account",
  authenticate,
  requireAdmin,
  async (req, res) => {
    const employeeId = normalizeEmployeeId(req.params.employeeId);
    if (!employeeId) return res.status(400).json({ ok: false, message: "Employee ID is required." });

    const defaultPassword = "112233";
    const resetPassword = req.body?.resetPassword === true;

    try {
      const email = String(req.body?.email || req.query?.email || "")
        .trim()
        .toLowerCase();
      if (!email || !email.includes("@")) {
        return res.status(400).json({
          ok: false,
          message: "A valid employee email address is required to create the login account.",
        });
      }
      const requestedActive = req.body?.isActive ?? req.query?.isActive;
      const isActive = ![false, "false", "0"].includes(requestedActive);
      const existing = await pool.query(
        `SELECT "id", "employeeId", "email" FROM public."app_user"
         WHERE UPPER(TRIM(COALESCE("employeeId", ''))) = $1
            OR LOWER(TRIM(COALESCE("email", ''))) = $2`,
        [employeeId, email],
      );

      if (existing.rowCount > 0) {
        const employeeAccount = existing.rows.find(
          (row) => normalizeEmployeeId(row.employeeId) === employeeId,
        );
        const emailAccount = existing.rows.find(
          (row) => String(row.email || "").trim().toLowerCase() === email,
        );
        if (employeeAccount && emailAccount && employeeAccount.id !== emailAccount.id) {
          return res.status(409).json({
            ok: false,
            message:
              "Two application accounts conflict for this employee ID and email. Remove or correct the duplicate app_user account first.",
          });
        }

        const account = employeeAccount || emailAccount;
        if (account.employeeId && normalizeEmployeeId(account.employeeId) !== employeeId) {
          return res.status(409).json({ ok: false, message: "That email address is already assigned to another employee login." });
        }
        if (resetPassword) {
          const passwordHash = await bcrypt.hash(defaultPassword, 12);
          await pool.query(
            `UPDATE public."app_user" SET "employeeId" = $2, "username" = $3,
             "email" = $3, "passwordHash" = $4, "role" = 'EMPLOYEE',
             "isActive" = $5, "mustChangePassword" = TRUE,
             "passwordChangedAt" = NULL, "updatedAt" = NOW()
             WHERE "id" = $1`,
            [account.id, employeeId, email, passwordHash, isActive],
          );
        } else {
          await pool.query(
            `UPDATE public."app_user" SET "employeeId" = $2, "username" = $3,
             "email" = $3, "role" = 'EMPLOYEE', "isActive" = $4, "updatedAt" = NOW()
             WHERE "id" = $1`,
            [account.id, employeeId, email, isActive],
          );
        }
        return res.json({
          ok: true,
          created: false,
          passwordReset: resetPassword,
          employeeId,
          email,
        });
      }

      const passwordHash = await bcrypt.hash(defaultPassword, 12);
      await pool.query(
        `INSERT INTO public."app_user" ("id", "employeeId", "username", "email",
          "passwordHash", "role", "isActive", "mustChangePassword", "passwordChangedAt", "createdAt", "updatedAt")
         VALUES ($1, $2, $3, $3, $4, 'EMPLOYEE', $5, TRUE, NULL, NOW(), NOW())`,
        [crypto.randomUUID(), employeeId, email, passwordHash, isActive],
      );
      return res.status(201).json({ ok: true, created: true, employeeId, email });
    } catch (error) {
      console.error("EMPLOYEE ACCOUNT PROVISION ERROR:", error.message);
      const errorCode = String(error.code || "database_error");
      return res.status(503).json({
        ok: false,
        message: `Unable to create or reset the application login (${errorCode}).`,
      });
    }
  },
);

app.post(
  "/api/admin/employees/:employeeId/status",
  authenticate,
  requireAdmin,
  async (req, res) => {
    const employeeId = String(req.params.employeeId ?? "").trim();
    const isActive = req.body?.isActive;

    if (!employeeId || typeof isActive !== "boolean") {
      return res.status(400).json({
        ok: false,
        message: "Employee ID and active status are required.",
      });
    }

    let client;
    try {
      client = await pool.connect();
      await client.query("BEGIN");
      const employeeResult = await client.query(
        `UPDATE public.employees
         SET is_active = $2, updated_at = NOW()
         WHERE UPPER(TRIM(employee_id)) = UPPER($1)
         RETURNING employee_id`,
        [employeeId, isActive],
      );

      if (employeeResult.rowCount === 0) {
        await client.query("ROLLBACK");
        return res.status(404).json({
          ok: false,
          message: "Employee was not found.",
        });
      }

      await client.query(
        `UPDATE public.app_user
         SET is_active = $2, updated_at = NOW()
         WHERE UPPER(TRIM(COALESCE(employee_id, ''))) = UPPER($1)`,
        [employeeId, isActive],
      );
      await client.query("COMMIT");

      return res.json({ ok: true, employeeId, isActive });
    } catch (error) {
      if (client) {
        try {
          await client.query("ROLLBACK");
        } catch (rollbackError) {
          console.error("EMPLOYEE STATUS ROLLBACK ERROR:", rollbackError.message);
        }
      }
      console.error("EMPLOYEE STATUS UPDATE ERROR:", error.message);
      return res.status(503).json({
        ok: false,
        message: "Unable to update employee status right now. Please try again.",
      });
    } finally {
      client?.release();
    }
  },
);

// Original Flutter admin dashboard, backed by existing Neon tables.
// Data shape mirrors the previous Supabase rows so the current UI can render
// without changes to its visual design. Only administrators may access it.
app.get("/api/admin/dashboard/overview", authenticate, requireAdmin, async (req, res) => {
  try {
    const year = Number(req.query.year);
    const month = Number(req.query.month);
    if (!Number.isInteger(year) || year < 2000 || year > 2100 ||
        !Number.isInteger(month) || month < 1 || month > 12) {
      return res.status(400).json({ ok: false, message: "Invalid dashboard month." });
    }
    const [employeesResult, payrollResult, branchesResult] = await Promise.all([
      pool.query("SELECT to_jsonb(e) AS row FROM public.employees e ORDER BY e.name ASC"),
      pool.query(
        `SELECT to_jsonb(p) AS row FROM public.payroll p
         WHERE p.period >= make_date($1, $2, 1)
           AND p.period < (make_date($1, $2, 1) + INTERVAL '1 month')
         ORDER BY p.employee_id ASC`,
        [year, month],
      ),
      pool.query("SELECT to_jsonb(b) AS row FROM public.branches b ORDER BY b.name ASC"),
    ]);
    const branches = branchesResult.rows.map(({row}) => {
      if (String(row.name ?? "").trim().toUpperCase() === "SUNGAI PETANI") {
        return {...row, name: "SP-EDAR", ...(Object.hasOwn(row,"branch_name") ? {branch_name:"SP-EDAR"} : {})};
      }
      return row;
    });
    return res.json({
      ok: true,
      source: "neon",
      employees: employeesResult.rows.map(({row}) => row),
      payroll: payrollResult.rows.map(({row}) => row),
      branches,
    });
  } catch (error) {
    console.error("NEON DASHBOARD OVERVIEW ERROR:", error.message);
    return res.status(503).json({ ok: false, message: "The Neon dashboard is temporarily unavailable." });
  }
});

// ADMIN / BRANCH PAYROLL — read directly from the existing Neon schema.
app.get(
  "/api/admin/payroll",
  authenticate,
  requireAdmin,
  async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT to_jsonb(p) AS data, to_jsonb(e) AS employee_data
         FROM public.payroll AS p
         LEFT JOIN public.employees AS e ON e.employee_id = p.employee_id
         ORDER BY p.period DESC, p.employee_id ASC`,
      );
      const payroll = result.rows.map((row) => ({
        ...row.data,
        employee: row.employee_data ?? null,
      }));
      return res.json({ ok: true, count: payroll.length, payroll });
    } catch (error) {
      console.error("ADMIN PAYROLL LIST ERROR:", error.message);
      return genericError(res, 503);
    }
  },
);

app.get(
  "/api/payroll",
  authenticate,
  async (req, res) => {
    try {
      const role = String(req.user?.role ?? "").toUpperCase();
      if (role !== "ADMIN" && role !== "BRANCH") {
        return res.status(403).json({ ok: false, message: "Administrator or branch access required." });
      }
      const year = req.query.year == null ? null : Number(req.query.year);
      const month = req.query.month == null ? null : Number(req.query.month);
      if ((year != null && (!Number.isInteger(year) || year < 2000 || year > 2100)) ||
          (month != null && (!Number.isInteger(month) || month < 1 || month > 12))) {
        return res.status(400).json({ ok: false, message: "Invalid payroll year or month." });
      }
      const params = [];
      const conditions = [];
      if (year != null) { params.push(year); conditions.push(`EXTRACT(YEAR FROM p.period) = $${params.length}`); }
      if (month != null) { params.push(month); conditions.push(`EXTRACT(MONTH FROM p.period) = $${params.length}`); }
      if (role === "BRANCH") {
        const branchId = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
        if (!branchId) return res.status(403).json({ ok: false, message: "Branch scope is missing for this account." });
        params.push(branchId);
        conditions.push(`(e.branch_id = $${params.length} OR e.payroll_branch_id = $${params.length})`);
      }
      const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
      const result = await pool.query(
        `SELECT to_jsonb(p) AS data, to_jsonb(e) AS employee_data
         FROM public.payroll AS p
         LEFT JOIN public.employees AS e ON e.employee_id = p.employee_id
         ${where}
         ORDER BY p.period DESC, p.employee_id ASC`,
        params,
      );
      const payroll = result.rows.map((row) => ({ ...row.data, employee: row.employee_data ?? null }));
      return res.json({ ok: true, count: payroll.length, payroll });
    } catch (error) {
      console.error("PAYROLL LIST ERROR:", error.message);
      return genericError(res, 503);
    }
  },
);


// Neon attendance listing with JWT-based role and branch scope.
app.get("/api/attendance", authenticate, async (req, res) => {
  try {
    const role = String(req.user?.role ?? "").toUpperCase();
    if (role !== "ADMIN" && role !== "BRANCH" && role !== "EMPLOYEE") {
      return res.status(403).json({ ok: false, message: "Access denied." });
    }
    const date = String(req.query.date ?? "").trim();
    const year = String(req.query.year ?? "").trim();
    const month = String(req.query.month ?? "").trim();
    const branch = String(req.query.branch_id ?? "").trim();
    if (date && !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return res.status(400).json({ ok: false, message: "Invalid date." });
    }
    if ((year && !/^\d{4}$/.test(year)) || (month && !/^(?:[1-9]|1[0-2])$/.test(month)) ||
        Boolean(year) !== Boolean(month)) {
      return res.status(400).json({ ok: false, message: "Invalid month." });
    }
    const conditions = [];
    const params = [];
    const add = (sql, value) => {
      params.push(value);
      conditions.push(sql.replace("?", "$" + params.length));
    };
    if (role === "BRANCH") {
      const scope = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
      if (!scope || (branch && branch.toLowerCase() !== scope.toLowerCase())) {
        return res.status(403).json({ ok: false, message: "Branch access denied." });
      }
      add("LOWER(TRIM(a.branch_id)) = LOWER(TRIM(?))", scope);
    } else if (role === "EMPLOYEE") {
      const employeeId = String(req.user.employeeId ?? req.user.employee_id ?? "").trim();
      if (!employeeId || branch) return res.status(403).json({ ok: false, message: "Access denied." });
      add("a.employee_id = ?", employeeId);
    } else if (branch) {
      add("LOWER(TRIM(a.branch_id)) = LOWER(TRIM(?))", branch);
    }
    if (date) add("a.attendance_date = ?::date", date);
    if (year && month) {
      const start = year + "-" + month.padStart(2, "0") + "-01";
      params.push(start);
      conditions.push("a.attendance_date >= $" + params.length + "::date");
      conditions.push("a.attendance_date < ($" + params.length + "::date + INTERVAL '1 month')");
    }
    const where = conditions.length ? "WHERE " + conditions.join(" AND ") : "";
    const result = await pool.query(
      "SELECT to_jsonb(a) AS data FROM public.attendance a " + where +
      " ORDER BY a.attendance_date DESC, a.employee_id ASC LIMIT 20000", params);
    return res.json({ ok: true, attendance: result.rows.map(r => r.data) });
  } catch (error) {
    console.error("ATTENDANCE LIST ERROR:", error.message);
    return genericError(res, 503);
  }
});

// Authenticated Neon daily reports list with server-enforced branch scope.
// Daily report creation is branch-scoped; caller cannot choose another branch.
app.post("/api/daily-reports", authenticate, async (req, res) => {
  try {
    if (String(req.user?.role ?? "").toUpperCase() !== "BRANCH") {
      return res.status(403).json({ ok: false, message: "Branch access required." });
    }
    const branch = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
    const body = req.body ?? {};
    const date = String(body.report_date ?? "");
    const reporter = String(req.user.username ?? req.user.displayName ?? "").trim();
    if (!branch || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !reporter || reporter.length > 200) {
      return res.status(400).json({ ok: false, message: "Valid date and reporter required." });
    }
    const fields = ["attendance","unpaid_leave","weekly_leave","annual_leave",
      "air_conditioner","maintenance_total","working_condition","service_repair",
      "maintenance_report","report_crew","recommendation","branch_stamp"];
    const values = fields.map((key) => String(body[key] ?? "").slice(0, 10000));
    const orsanco = body.orsanco && typeof body.orsanco === "object" &&
      !Array.isArray(body.orsanco) ? body.orsanco : {};
    const cols = ["branch_id","report_date","reported_by",...fields,"orsanco"];
    const params = [branch,date,reporter,...values,JSON.stringify(orsanco)];
    const markers = params.map((_, i) => "$" + (i + 1) +
      (i === 1 ? "::date" : i === params.length - 1 ? "::jsonb" : ""));
    const result = await pool.query(
      "INSERT INTO public.daily_reports (" + cols.join(",") + ") VALUES (" +
      markers.join(",") + ") RETURNING id", params);
    return res.status(201).json({ ok: true, id: result.rows[0].id });
  } catch (error) {
    console.error("DAILY REPORT CREATE ERROR:", error.message);
    return genericError(res, 503);
  }
});

// HQ review is restricted to administrators.
app.post("/api/daily-reports/review", authenticate, async (req, res) => {
  try {
    if (String(req.user?.role ?? "").toUpperCase() !== "ADMIN") {
      return res.status(403).json({ ok: false, message: "Administrator access required." });
    }
    const id = String(req.body?.id ?? "").trim();
    const comment = String(req.body?.comment ?? "").trim();
    const reviewer = String(req.user.username ?? req.user.displayName ?? "").trim();
    if (!/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(id) ||
        comment.length > 10000 || !reviewer || reviewer.length > 200) {
      return res.status(400).json({ ok: false, message: "Valid report and reviewer required." });
    }
    const result = await pool.query(
      `UPDATE public.daily_reports SET hq_comment = $2, reviewed_by = $3,
       reviewed_at = NOW(), updated_at = NOW()
       WHERE id = $1::uuid RETURNING id`, [id, comment, reviewer]);
    if (!result.rowCount) return res.status(404).json({ ok: false, message: "Report not found." });
    return res.json({ ok: true });
  } catch (error) {
    console.error("DAILY REPORT REVIEW ERROR:", error.message);
    return genericError(res, 503);
  }
});

app.get("/api/daily-reports", authenticate, async (req, res) => {
  try {
    const role = String(req.user?.role ?? "").toUpperCase();
    const date = req.query.date == null ? "" : String(req.query.date);
    if (date && !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return res.status(400).json({ ok: false, message: "Invalid report date." });
    }
    const params = [];
    const conditions = [];
    if (role === "BRANCH") {
      const branch = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
      if (!branch) return res.status(403).json({ ok: false, message: "Branch scope missing." });
      params.push(branch);
      conditions.push("LOWER(TRIM(d.branch_id)) = LOWER(TRIM($" + params.length + "))");
    } else if (role !== "ADMIN") {
      return res.status(403).json({ ok: false, message: "Access denied." });
    }
    if (date) {
      params.push(date);
      conditions.push("d.report_date = $" + params.length + "::date");
    }
    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
    const result = await pool.query(
      `SELECT to_jsonb(d) AS data FROM public.daily_reports AS d
       ${where} ORDER BY d.report_date DESC`,
      params,
    );
    return res.json({ ok: true, reports: result.rows.map((row) => row.data) });
  } catch (error) {
    console.error("DAILY REPORT LIST ERROR:", error.message);
    return genericError(res, 503);
  }
});

// Authenticated branch OT review, with conditional state transition and branch scope.
app.post("/api/ot-requests/branch-review", authenticate, async (req, res) => {
  try {
    if (String(req.user?.role ?? "").toUpperCase() !== "BRANCH") {
      return res.status(403).json({ ok: false, message: "Branch access required." });
    }
    const branch = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
    const id = String(req.body?.requestId ?? "").trim();
    const approve = req.body?.approve;
    const name = String(req.body?.approvedByName ?? "").trim();
    if (!branch || !/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(id) ||
        typeof approve !== "boolean" || (approve && (!name || name.length > 200))) {
      return res.status(400).json({ ok: false, message: "Valid branch, request and decision required." });
    }
    const result = await pool.query(
      `UPDATE public.overtime_requests
       SET status = $3,
           branch_approved_at = CASE WHEN $4 THEN NOW() ELSE NULL END,
           branch_approved_name = CASE WHEN $4 THEN $5 ELSE NULL END,
           reviewed_at = CASE WHEN $4 THEN reviewed_at ELSE NOW() END
       WHERE id = $1::uuid AND status = 'pending_branch'
         AND LOWER(TRIM(branch_id)) = LOWER(TRIM($2))
       RETURNING id, status`,
      [id, branch, approve ? "pending_admin" : "rejected", approve, name],
    );
    if (!result.rowCount) return res.status(409).json({ ok: false, message: "Request not found, already reviewed or out of branch scope." });
    return res.json({ ok: true, request: result.rows[0] });
  } catch (error) {
    console.error("BRANCH OT REVIEW ERROR:", error.message);
    return genericError(res, 503);
  }
});

// Role-scoped overtime listing through Neon.
app.get("/api/ot-requests", authenticate, async (req, res) => {
  try {
    const role = String(req.user?.role ?? "").toUpperCase();
    const params = [];
    let scope = "";
    if (role === "BRANCH") {
      const branch = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
      if (!branch) return res.status(403).json({ ok: false, message: "Branch scope missing." });
      params.push(branch);
      scope = "WHERE LOWER(TRIM(o.branch_id)) = LOWER(TRIM($1))";
    } else if (role === "EMPLOYEE") {
      const employeeId = normalizeEmployeeId(req.user.employeeId ?? req.user.employee_id);
      if (!employeeId) return res.status(403).json({ ok: false, message: "Employee scope missing." });
      params.push(employeeId);
      scope = "WHERE UPPER(TRIM(o.employee_id)) = $1";
    } else if (role !== "ADMIN") {
      return res.status(403).json({ ok: false, message: "Access denied." });
    }
    const result = await pool.query(
      `SELECT to_jsonb(o) AS data FROM public.overtime_requests AS o
       ${scope} ORDER BY o.submitted_at DESC`,
      params,
    );
    return res.json({ ok: true, requests: result.rows.map((row) => row.data) });
  } catch (error) {
    console.error("OT REQUESTS LIST ERROR:", error.message);
    return genericError(res, 503);
  }
});

// Server-authorized leave approvals. Conditional status update prevents double review.
app.post("/api/leave-requests/review", authenticate, async (req, res) => {
  try {
    const role = String(req.user?.role ?? "").toUpperCase();
    const id = String(req.body?.requestId ?? "").trim();
    const approve = req.body?.approve;
    const remarks = String(req.body?.remarks ?? "").trim();
    const approverName = String(req.body?.approverName ?? "").trim();
    if (!id || id.length > 100 || typeof approve !== "boolean" || !remarks || remarks.length > 2000) {
      return res.status(400).json({ ok: false, message: "Valid request, decision and remarks required." });
    }
    if (role !== "ADMIN" && role !== "BRANCH") {
      return res.status(403).json({ ok: false, message: "Approval access required." });
    }
    const params = [id];
    let sql;
    if (role === "BRANCH") {
      const branch = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
      if (!branch || !approverName || approverName.length > 200) {
        return res.status(400).json({ ok: false, message: "Branch and approver name required." });
      }
      params.push(branch, remarks, approverName, approve ? "pending_admin" : "rejected");
      sql = `UPDATE public.leave_requests
        SET status = $5, branch_remarks = $3,
            branch_approved_at = CASE WHEN $5 = 'pending_admin' THEN NOW() ELSE NULL END,
            branch_approved_by = NULL,
            branch_approved_name = CASE WHEN $5 = 'pending_admin' THEN $4 ELSE NULL END
        WHERE id::text = $1 AND status = 'pending_branch'
          AND LOWER(TRIM(branch_id)) = LOWER(TRIM($2))
        RETURNING id, status`;
    } else {
      params.push(remarks, approve ? "approved" : "rejected");
      sql = `UPDATE public.leave_requests
        SET status = $3, admin_remarks = $2,
            admin_approved_at = CASE WHEN $3 = 'approved' THEN NOW() ELSE NULL END,
            admin_approved_by = NULL
        WHERE id::text = $1 AND status = 'pending_admin'
        RETURNING id, status`;
    }
    const result = await pool.query(sql, params);
    if (!result.rowCount) return res.status(409).json({ ok: false, message: "Request not found, out of scope, or already reviewed." });
    return res.json({ ok: true, request: result.rows[0] });
  } catch (error) {
    console.error("LEAVE REVIEW ERROR:", error.message);
    return genericError(res, 503);
  }
});

// Authenticated leave request listing. Approval mutations remain on the legacy path.
app.get("/api/leave-requests", authenticate, async (req, res) => {
  try {
    const role = String(req.user?.role ?? "").toUpperCase();
    const params = [];
    let scope = "";
    if (role === "BRANCH") {
      const branch = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
      if (!branch) return res.status(403).json({ ok: false, message: "Branch scope missing." });
      params.push(branch);
      scope = "WHERE LOWER(TRIM(l.branch_id)) = LOWER(TRIM($1))";
    } else if (role === "EMPLOYEE") {
      const employeeId = normalizeEmployeeId(req.user.employeeId ?? req.user.employee_id);
      if (!employeeId) return res.status(403).json({ ok: false, message: "Employee scope missing." });
      params.push(employeeId);
      scope = "WHERE UPPER(TRIM(l.employee_id)) = $1";
    } else if (role !== "ADMIN") {
      return res.status(403).json({ ok: false, message: "Access denied." });
    }
    const result = await pool.query(
      `SELECT to_jsonb(l) AS data FROM public.leave_requests AS l
       ${scope} ORDER BY l.submitted_at DESC`,
      params,
    );
    return res.json({ ok: true, requests: result.rows.map((row) => row.data) });
  } catch (error) {
    console.error("LEAVE REQUESTS LIST ERROR:", error.message);
    return genericError(res, 503);
  }
});

// Read-only EA forms: authenticated, scoped, and backed by Neon.
app.get("/api/ea-forms", authenticate, async (req, res) => {
  try {
    const year = Number(req.query.year);
    if (!Number.isInteger(year) || year < 2000 || year > 2100) {
      return res.status(400).json({ ok: false, message: "Invalid tax year." });
    }
    const role = String(req.user?.role ?? "").toUpperCase();
    const params = [year];
    let scope = "";
    if (role === "EMPLOYEE") {
      const id = normalizeEmployeeId(req.user.employeeId ?? req.user.employee_id);
      if (!id) return res.status(403).json({ ok: false, message: "Employee scope missing." });
      params.push(id);
      scope = "AND UPPER(TRIM(f.employee_id)) = $2";
    } else if (role !== "ADMIN") {
      return res.status(403).json({ ok: false, message: "Access denied." });
    }
    const result = await pool.query(
      `SELECT to_jsonb(f) AS data FROM public.employee_ea_forms AS f
       WHERE f.tax_year = $1 ${scope} ORDER BY f.employee_id ASC`,
      params,
    );
    return res.json({ ok: true, forms: result.rows.map((row) => row.data) });
  } catch (error) {
    console.error("EA FORMS LIST ERROR:", error.message);
    return genericError(res, 503);
  }
});

app.get(
  "/api/employees",
  authenticate,
  async (req, res) => {
    try {
      const role = String(req.user?.role ?? "").toUpperCase();
      const params = [];
      let where = "";
      if (role === "EMPLOYEE") {
        const employeeId = normalizeEmployeeId(req.user.employeeId ?? req.user.employee_id);
        if (!employeeId) return res.status(403).json({ ok: false, message: "Employee scope is missing." });
        params.push(employeeId);
        where = "WHERE UPPER(TRIM(e.employee_id)) = $1";
      } else if (role === "BRANCH") {
        const branchId = String(req.user.branchId ?? req.user.branch_id ?? "").trim();
        if (!branchId) return res.status(403).json({ ok: false, message: "Branch scope is missing." });
        params.push(branchId);
        where = "WHERE e.branch_id = $1 OR e.payroll_branch_id = $1";
      } else if (role !== "ADMIN") {
        return res.status(403).json({ ok: false, message: "Access denied." });
      }
      const result = await pool.query(
        `SELECT to_jsonb(e) AS data FROM public.employees AS e ${where} ORDER BY e.employee_id ASC`,
        params,
      );
      const employees = result.rows.map((row) => row.data);
      return res.json({ ok: true, count: employees.length, employees });
    } catch (error) {
      console.error("EMPLOYEE LIST ERROR:", error.message);
      return genericError(res, 503);
    }
  },
);

app.get(
  "/api/employees/:employeeId",
  authenticate,
  async (req, res) => {
    try {
      const employeeId = normalizeEmployeeId(req.params.employeeId);
      const role = String(req.user?.role ?? "").toUpperCase();
      if (!isValidEmployeeId(employeeId)) return res.status(400).json({ ok: false, message: "Invalid employee ID." });
      if (role === "EMPLOYEE" && normalizeEmployeeId(req.user.employeeId ?? req.user.employee_id) !== employeeId) {
        return res.status(403).json({ ok: false, message: "Not authorized." });
      }
      const result = await pool.query(
        `SELECT to_jsonb(e) AS data FROM public.employees AS e
         WHERE UPPER(TRIM(e.employee_id)) = $1 LIMIT 1`,
        [employeeId],
      );
      const employee = result.rows[0]?.data;
      if (!employee) return res.status(404).json({ ok: false, message: "Employee not found." });
      if (role === "BRANCH" && String(employee.branch_id ?? employee.payroll_branch_id ?? "") !== String(req.user.branchId ?? req.user.branch_id ?? "")) {
        return res.status(403).json({ ok: false, message: "Not authorized." });
      }
      return res.json({ ok: true, employee });
    } catch (error) {
      console.error("EMPLOYEE LOOKUP ERROR:", error.message);
      return genericError(res, 503);
    }
  },
);

// EMPLOYEE PAYROLL
app.get(
  "/api/employees/:employeeId/payroll",
  authenticate,
  requireEmployeeAccess,
  async (req, res) => {
    try {
      const employeeId = normalizeEmployeeId(req.params.employeeId);
      if (!isValidEmployeeId(employeeId)) return res.status(400).json({ ok: false, message: "Invalid employee ID." });
      const year = req.query.year == null ? null : Number(req.query.year);
      const month = req.query.month == null ? null : Number(req.query.month);
      if ((year != null && (!Number.isInteger(year) || year < 2000 || year > 2100)) ||
          (month != null && (!Number.isInteger(month) || month < 1 || month > 12))) {
        return res.status(400).json({ ok: false, message: "Invalid payroll year or month." });
      }
      const params = [employeeId];
      const conditions = ["UPPER(TRIM(p.employee_id)) = $1", "p.is_published = TRUE"];
      if (year != null) { params.push(year); conditions.push(`EXTRACT(YEAR FROM p.period) = $${params.length}`); }
      if (month != null) { params.push(month); conditions.push(`EXTRACT(MONTH FROM p.period) = $${params.length}`); }
      const employeeResult = await pool.query(
        `SELECT to_jsonb(e) AS data FROM public.employees e WHERE UPPER(TRIM(e.employee_id)) = $1 LIMIT 1`,
        [employeeId],
      );
      const employee = employeeResult.rows[0]?.data;
      if (!employee) return res.status(404).json({ ok: false, message: "Employee not found." });
      const result = await pool.query(
        `SELECT to_jsonb(p) AS data FROM public.payroll p WHERE ${conditions.join(" AND ")} ORDER BY p.period DESC`,
        params,
      );
      const payroll = result.rows.map((row) => row.data);
      return res.json({ ok: true, employee, count: payroll.length, payroll });
    } catch (error) {
      console.error("EMPLOYEE PAYROLL ERROR:", error.message);
      return genericError(res, 503);
    }
  },
);

// SINGLE PAYSLIP
app.get(
  "/api/employees/:employeeId/payroll/:year/:month",
  authenticate,
  requireEmployeeAccess,
  async (req, res) => {
    try {
      const employeeId = normalizeEmployeeId(req.params.employeeId);
      const year = Number(req.params.year);
      const month = Number(req.params.month);
      if (!isValidEmployeeId(employeeId) || !Number.isInteger(year) || year < 2000 || year > 2100 ||
          !Number.isInteger(month) || month < 1 || month > 12) {
        return res.status(400).json({ ok: false, message: "Invalid employee ID, year or month." });
      }
      const result = await pool.query(
        `SELECT to_jsonb(p) AS data, to_jsonb(e) AS employee_data
         FROM public.payroll p LEFT JOIN public.employees e ON e.employee_id = p.employee_id
         WHERE UPPER(TRIM(p.employee_id)) = $1 AND p.is_published = TRUE
           AND EXTRACT(YEAR FROM p.period) = $2 AND EXTRACT(MONTH FROM p.period) = $3
         ORDER BY p.period DESC LIMIT 1`,
        [employeeId, year, month],
      );
      const row = result.rows[0];
      if (!row) return res.status(404).json({ ok: false, message: "Payslip not found." });
      return res.json({ ok: true, payroll: { ...row.data, employee: row.employee_data ?? null } });
    } catch (error) {
      console.error("PAYSLIP ERROR:", error.message);
      return genericError(res, 503);
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

        const employeeResult = await pool.query(
          `SELECT to_jsonb(e) AS data
           FROM public.employees e
           WHERE UPPER(TRIM(e.employee_id)) = $1
           LIMIT 1`,
          [employeeId],
        );
        const employee = employeeResult.rows[0]?.data
          ? {
              ...employeeResult.rows[0].data,
              bankCode: employeeResult.rows[0].data.bank_code,
              bankAccount: employeeResult.rows[0].data.bank_account,
              newIcNo: employeeResult.rows[0].data.new_ic_no,
            }
          : null;

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

        const existed = await pool.query(
          `SELECT 1 FROM public.payroll
           WHERE employee_id = $1 AND period = $2::date
           LIMIT 1`,
          [employeeId, normalizedPeriod.toISOString().slice(0, 10)],
        );

        const value = (snake, camel, fallback = 0) =>
          safeNumber(row[snake] ?? row[camel] ?? fallback);
        const bonus = row.bonus == null ? null : String(row.bonus).slice(0, 1000);
        const commission = row.commission == null ? null : String(row.commission).slice(0, 1000);
        const otherEarnings = row.other_earnings == null && row.otherEarnings == null
          ? null : String(row.other_earnings ?? row.otherEarnings).slice(0, 1000);
        await pool.query(
          `INSERT INTO public.payroll (
             id, employee_id, period, basic_salary, fw_salary,
             elaun_kedatangan, elaun_perkhidmatan, elaun_kerajinan, elaun_makanan,
             overtime, cuti_umum, epf_employee, socso_employee, eis_employee, pcb, zakat,
             epf_employer, socso_employer, eis_employer, new_ic_no, bank_code, bank_account,
             remarks, late_deduction, unpaid_deduction, bonus, commission, other_earnings,
             advance, is_published, published_at, published_by, release_at, created_at, updated_at
           ) VALUES (
             $1,$2,$3::date,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,
             $17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,FALSE,NULL,NULL,NULL,NOW(),NOW()
           )
           ON CONFLICT (employee_id, period) DO UPDATE SET
             basic_salary = EXCLUDED.basic_salary,
             fw_salary = EXCLUDED.fw_salary,
             elaun_kedatangan = EXCLUDED.elaun_kedatangan,
             elaun_perkhidmatan = EXCLUDED.elaun_perkhidmatan,
             elaun_kerajinan = EXCLUDED.elaun_kerajinan,
             elaun_makanan = EXCLUDED.elaun_makanan,
             overtime = EXCLUDED.overtime,
             cuti_umum = EXCLUDED.cuti_umum,
             epf_employee = EXCLUDED.epf_employee,
             socso_employee = EXCLUDED.socso_employee,
             eis_employee = EXCLUDED.eis_employee,
             pcb = EXCLUDED.pcb,
             epf_employer = EXCLUDED.epf_employer,
             socso_employer = EXCLUDED.socso_employer,
             eis_employer = EXCLUDED.eis_employer,
             new_ic_no = EXCLUDED.new_ic_no,
             bank_code = EXCLUDED.bank_code,
             bank_account = EXCLUDED.bank_account,
             remarks = EXCLUDED.remarks,
             late_deduction = EXCLUDED.late_deduction,
             unpaid_deduction = EXCLUDED.unpaid_deduction,
             bonus = EXCLUDED.bonus,
             commission = EXCLUDED.commission,
             other_earnings = EXCLUDED.other_earnings,
             advance = EXCLUDED.advance,
             updated_at = NOW()`,
          [
            crypto.randomUUID(), employeeId, normalizedPeriod.toISOString().slice(0, 10),
            payrollData.basicSalary,
            value("fw_salary", "fwSalary", employee.fw_salary),
            value("elaun_kedatangan", "elaunKedatangan", employee.elaun_kedatangan),
            value("elaun_perkhidmatan", "elaunPerkhidmatan", employee.elaun_perkhidmatan),
            value("elaun_kerajinan", "elaunKerajinan", employee.elaun_kerajinan),
            payrollData.foodAllowance,
            payrollData.overtime,
            value("cuti_umum", "cutiUmum"),
            payrollData.epfEmployee,
            payrollData.socsoEmployee,
            payrollData.eisEmployee,
            payrollData.pcb,
            value("zakat", "zakat"),
            payrollData.epfEmployer,
            payrollData.socsoEmployer,
            payrollData.eisEmployer,
            String(row.new_ic_no ?? row.newIcNo ?? employee.new_ic_no ?? "").slice(0, 100),
            payrollData.bankCode,
            payrollData.bankAccount,
            payrollData.remarks,
            value("late_deduction", "lateDeduction"),
            value("unpaid_deduction", "unpaidDeduction"),
            bonus, commission, otherEarnings,
            value("advance", "advance"),
          ],
        );

        if (existed.rowCount > 0) {
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

      const deleted = await pool.query(
        `DELETE FROM public.payroll WHERE id = $1 RETURNING id`,
        [id],
      );

      if (deleted.rowCount === 0) {
        return res.status(404).json({
          ok: false,
          message: "Payroll record not found.",
        });
      }

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

  // ========================================================================
  // PRIORITY 1: RESEND (Most reliable on Render - uses HTTPS port 443)
  // ========================================================================
  if (resendApiKey) {
    console.log("📧 Attempting to send OTP via Resend...");
    
    const fromAddress = String(
      process.env.RESEND_FROM ||
        process.env.SMTP_FROM ||
        "Hasani Payroll <onboarding@resend.dev>",
    )
      .replace(/['"\r\n]/g, "")
      .trim();

    try {
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
      
      console.log(`✅ OTP sent via Resend to ${email}`);
      return;
    } catch (error) {
      console.error("Resend failed; trying SMTP fallback:", error.message);
    }
  }

  // ========================================================================
  // PRIORITY 2: SMTP (May be blocked on Render - uses port 587)
  // ========================================================================
  if (smtpUser && smtpPassword) {
    console.log("📧 Attempting to send OTP via SMTP...");
    
    try {
      const transporter = createMailTransporter();

      const rawFrom = String(
        process.env.SMTP_FROM ||
          process.env.MAIL_FROM ||
          process.env.EMAIL_FROM ||
          "",
      )
        .replace(/['"\r\n]/g, "")
        .trim();

      const from =
        rawFrom ||
        `Hasani Payroll <${smtpUser}>`;

      await transporter.sendMail(
        {
          from,
          to: email,
          subject: "Hasani Payroll - Verification Code",
          text: textBody,
          html: htmlBody,
        },
      );

      console.log(`✅ OTP sent via SMTP to ${email}`);
      return;
    } catch (smtpError) {
      console.error("❌ SMTP failed:", smtpError.message);
      // Don't throw - fall through to console logging
    }
  }

  // Never disclose OTPs in production logs. Console delivery is available only
  // for an explicitly non-production local development environment.
  if (process.env.NODE_ENV !== "production") {
    console.warn("Email provider unavailable; local development OTP:", otp);
    return;
  }

  throw new Error("OTP email delivery is unavailable. Configure a valid email provider.");}

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
        
        console.log("✅ OTP generation successful for user:", user.username);
      } catch (emailError) {
        console.error(
          "🔴 OTP EMAIL ERROR:",
          emailError.message,
        );

        // Rollback database changes since email ultimately failed
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
            "Unable to send OTP. Please try again or contact support.",
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
            "First-login session has expired. Please login again.",
        });
      }

      const isOtpVerification =
        session.type ===
        "otp-verification";

      const isFirstLoginPassword =
        session.type ===
        "first-login-password";

      if (!isOtpVerification && !isFirstLoginPassword) {
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

      const reusesDefaultPassword =
        await verifyPassword(
          newPassword,
          user.passwordHash,
        );

      if (reusesDefaultPassword) {
        return res.status(400).json({
          ok: false,
          message:
            "Your new password must be different from the default password.",
        });
      }

      if (isOtpVerification) {
        if (!user.otpVerifiedAt) {
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
              "Verification session has expired. Please login again.",
          });
        }
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
      const dataAccessToken =
        createDataApiAccessToken(
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

        ...(dataAccessToken ? { dataAccessToken } : {}),

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
// ============================================================
// NEON DEV FLUTTER PREVIEW — safe, read-only employee directory
// ============================================================
// This endpoint deliberately returns only non-sensitive directory fields.
// Employee and branch scope are enforced by the backend; never return full
// employee rows to the browser, as they contain identity/payroll data.
app.get("/api/neon/preview/employees", authenticate, async (req, res) => {
  try {
    const role = String(req.user?.role ?? "").trim().toUpperCase();
    const employeeId = normalizeEmployeeId(req.user?.employeeId);
    const branchId = String(req.user?.branch_id ?? req.user?.branchId ?? "").trim();
    const params = [];
    let predicate = "";

    if (role === "EMPLOYEE") {
      if (!isValidEmployeeId(employeeId)) {
        return res.status(403).json({ok:false,message:"Employee scope missing."});
      }
      params.push(employeeId);
      predicate = "WHERE UPPER(TRIM(e.employee_id)) = $1";
    } else if (role === "BRANCH") {
      if (!branchId) {
        return res.status(403).json({ok:false,message:"Branch scope missing."});
      }
      params.push(branchId);
      predicate = "WHERE e.branch_id = $1";
    } else if (role !== "ADMIN") {
      return res.status(403).json({ok:false,message:"Role is not authorized."});
    }

    const result = await pool.query(
      `SELECT e.employee_id, e.name, e.branch_id, e.department, e.designation,
              e.is_active, e.employment_status
       FROM public.employees AS e
       ${predicate}
       ORDER BY e.name, e.employee_id
       LIMIT 500`,
      params,
    );
    return res.json({
      ok:true,
      source:"neon",
      count:result.rows.length,
      employees:result.rows,
    });
  } catch (error) {
    console.error("NEON PREVIEW DIRECTORY ERROR:", error.message);
    return res.status(503).json({ok:false,message:"Unable to load Neon employee directory."});
  }
});

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
      "🔴 UNHANDLED API ERROR:",
      error.message || error,
    );

    console.error(
      "Path:",
      req.path,
    );

    console.error(
      "Method:",
      req.method,
    );

    if (
      res.headersSent
    ) {
      console.error(
        "Headers already sent, cannot respond",
      );
      return next(error);
    }

    res.status(500).json({
      ok: false,
      message:
        "Internal server error. Please try again.",
      error: process.env.NODE_ENV === "development"
        ? error.message
        : undefined,
    });
  },
);

// Global unhandled rejection handler
process.on(
  "unhandledRejection",
  (reason, promise) => {
    console.error(
      "🔴 UNHANDLED REJECTION:",
      reason,
    );
  },
);

// Global uncaught exception handler
process.on(
  "uncaughtException",
  (error) => {
    console.error(
      "🔴 UNCAUGHT EXCEPTION:",
      error,
    );
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

function matchesConfiguredPassword(enteredPassword, configuredPassword) {
  const entered = Buffer.from(String(enteredPassword ?? ""), "utf8");
  const configured = Buffer.from(String(configuredPassword ?? ""), "utf8");
  return entered.length > 0 &&
    entered.length === configured.length &&
    crypto.timingSafeEqual(entered, configured);
}
// ============================================================
// SERVER
// ============================================================

let server;

async function startServer() {
  await testDatabase();
  const hashPassword = (password) => bcrypt.hash(password, 12);
  await ensureAdminAccount(pool, {
    email: process.env.ADMIN_EMAIL,
    password: process.env.ADMIN_PASSWORD,
    hashPassword,
  });
  await ensurePlayReviewerAccount(pool, {
    username: PLAY_REVIEWER_USERNAME,
    email: PLAY_REVIEWER_EMAIL,
    employeeId: PLAY_REVIEWER_EMPLOYEE_ID,
    password: PLAY_REVIEWER_PASSWORD,
    hashPassword,
  });
  await ensureFrnBranchAccounts(pool, {
    password: process.env.FRN_BRANCH_PASSWORD,
    hashPassword,
  });

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

