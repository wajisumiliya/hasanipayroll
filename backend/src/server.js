import "dotenv/config";
import express from "express";
import cors from "cors";
import bcrypt from "bcryptjs";
import pg from "pg";
import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const app = express();

app.use(cors());
app.use(express.json({ limit: "10mb" }));

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
// HELPERS
// ============================================================

function numberValue(value) {
  if (value === null || value === undefined || value === "") {
    return 0;
  }

  const cleaned = String(value)
    .replace(/RM/gi, "")
    .replace(/,/g, "")
    .trim();

  const result = Number(cleaned);

  return Number.isFinite(result) ? result : 0;
}

function formatPayroll(record) {
  const r = {
    ...record,

    basicSalary: Number(record.basicSalary),
    foodAllowance: Number(record.foodAllowance),
    otherAllowance: Number(record.otherAllowance),
    overtime: Number(record.overtime),
    bonus: Number(record.bonus),
    commission: Number(record.commission),
    otherEarnings: Number(record.otherEarnings),

    epfEmployee: Number(record.epfEmployee),
    socsoEmployee: Number(record.socsoEmployee),
    eisEmployee: Number(record.eisEmployee),
    pcb: Number(record.pcb),
    otherDeduction: Number(record.otherDeduction),

    epfEmployer: Number(record.epfEmployer),
    socsoEmployer: Number(record.socsoEmployer),
    eisEmployer: Number(record.eisEmployer),
  };

  r.totalEarnings =
    r.basicSalary +
    r.foodAllowance +
    r.otherAllowance +
    r.overtime +
    r.bonus +
    r.commission +
    r.otherEarnings;

  r.totalDeductions =
    r.epfEmployee +
    r.socsoEmployee +
    r.eisEmployee +
    r.pcb +
    r.otherDeduction;

  r.netPay = r.totalEarnings - r.totalDeductions;

  return r;
}

// ============================================================
// ROOT
// ============================================================

app.get("/", (req, res) => {
  res.json({
    name: "Hasani Payroll API",
    status: "online",
    version: "1.0.0",
  });
});

// ============================================================
// HEALTH
// ============================================================

app.get("/health", async (req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;

    res.json({
      ok: true,
      database: "connected",
      message: "Hasani Payroll API is running",
      time: new Date().toISOString(),
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      database: "disconnected",
      message: error.message,
    });
  }
});

// ============================================================
// LOGIN
// ============================================================

app.post("/api/auth/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        ok: false,
        message: "Username and password are required.",
      });
    }

    const login = String(username).trim();

    const user = await prisma.user.findFirst({
      where: {
        OR: [
          {
            email: {
              equals: login,
              mode: "insensitive",
            },
          },
          {
            employeeId: login.toUpperCase(),
          },
        ],
      },

      include: {
        employee: true,
      },
    });

    if (!user) {
      return res.status(401).json({
        ok: false,
        message: "Invalid username or password.",
      });
    }

    if (!user.isActive) {
      return res.status(403).json({
        ok: false,
        message: "This account is inactive.",
      });
    }

    const validPassword = await bcrypt.compare(
      password,
      user.passwordHash,
    );

    if (!validPassword) {
      return res.status(401).json({
        ok: false,
        message: "Invalid username or password.",
      });
    }

    res.json({
      ok: true,

      user: {
        id: user.id,
        role: user.role,
        employeeId: user.employeeId,
        email: user.email,
        employee: user.employee,
      },
    });
  } catch (error) {
    console.error("LOGIN ERROR:", error);

    res.status(500).json({
      ok: false,
      message: "Login failed.",
      error: error.message,
    });
  }
});

// ============================================================
// ADMIN - GET ALL EMPLOYEES
// ============================================================

app.get("/api/admin/employees", async (req, res) => {
  try {
    const employees = await prisma.employee.findMany({
      orderBy: {
        employeeId: "asc",
      },
    });

    res.json({
      ok: true,
      count: employees.length,
      employees,
    });
  } catch (error) {
    console.error("EMPLOYEE LIST ERROR:", error);

    res.status(500).json({
      ok: false,
      message: error.message,
    });
  }
});

// ============================================================
// ADMIN - GET ALL PAYROLL RECORDS
// ============================================================

app.get("/api/admin/payroll", async (req, res) => {
  try {
    const records = await prisma.payrollRecord.findMany({
      include: {
        employee: true,
      },
      orderBy: [
        {
          period: "desc",
        },
        {
          employeeId: "asc",
        },
      ],
    });

    res.json({
      ok: true,
      count: records.length,
      payroll: records.map(formatPayroll),
    });
  } catch (error) {
    console.error("PAYROLL LIST ERROR:", error);

    res.status(500).json({
      ok: false,
      message: error.message,
    });
  }
});

// ============================================================
// EMPLOYEE - PAYROLL HISTORY
// ============================================================

app.get("/api/employees/:employeeId/payroll", async (req, res) => {
  try {
    const { employeeId } = req.params;

    const employee = await prisma.employee.findUnique({
      where: {
        employeeId,
      },
    });

    if (!employee) {
      return res.status(404).json({
        ok: false,
        message: "Employee not found.",
      });
    }

    const payroll = await prisma.payrollRecord.findMany({
      where: {
        employeeId,
      },

      orderBy: {
        period: "desc",
      },
    });

    res.json({
      ok: true,
      employee,
      count: payroll.length,
      payroll: payroll.map(formatPayroll),
    });
  } catch (error) {
    console.error("EMPLOYEE PAYROLL ERROR:", error);

    res.status(500).json({
      ok: false,
      message: error.message,
    });
  }
});

// ============================================================
// SINGLE PAYSLIP
// ============================================================

app.get(
  "/api/employees/:employeeId/payroll/:year/:month",
  async (req, res) => {
    try {
      const { employeeId, year, month } = req.params;

      const period = new Date(
        Date.UTC(
          Number(year),
          Number(month) - 1,
          1,
        ),
      );

      const payroll = await prisma.payrollRecord.findUnique({
        where: {
          employeeId_period: {
            employeeId,
            period,
          },
        },

        include: {
          employee: true,
        },
      });

      if (!payroll) {
        return res.status(404).json({
          ok: false,
          message: "Payslip not found.",
        });
      }

      res.json({
        ok: true,
        payroll: formatPayroll(payroll),
      });
    } catch (error) {
      console.error("PAYSLIP ERROR:", error);

      res.status(500).json({
        ok: false,
        message: error.message,
      });
    }
  },
);

// ============================================================
// PAYROLL IMPORT
//
// Flutter sends parsed CSV rows as JSON.
// This avoids needing file upload middleware.
//
// Required columns:
//
// employee_id
// period
// basic_salary
//
// Optional columns are automatically handled.
// ============================================================

app.post("/api/admin/payroll/import", async (req, res) => {
  try {
    const { rows } = req.body;

    if (!Array.isArray(rows) || rows.length === 0) {
      return res.status(400).json({
        ok: false,
        message: "No payroll rows received.",
      });
    }

    const results = {
      total: rows.length,
      imported: 0,
      updated: 0,
      errors: [],
    };

    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];

      const rowNumber = index + 2;

      const employeeId = String(
        row.employee_id ??
        row.employeeId ??
        "",
      )
        .trim()
        .toUpperCase();

      const periodText = String(
        row.period ?? "",
      ).trim();

      // --------------------------------------------------------
      // VALIDATE EMPLOYEE ID
      // --------------------------------------------------------

      if (!employeeId) {
        results.errors.push({
          row: rowNumber,
          message: "Missing employee_id.",
        });

        continue;
      }

      // --------------------------------------------------------
      // VALIDATE PERIOD
      // --------------------------------------------------------

      const period = new Date(periodText);

      if (
        !periodText ||
        Number.isNaN(period.getTime())
      ) {
        results.errors.push({
          row: rowNumber,
          employeeId,
          message: `Invalid period: ${periodText}`,
        });

        continue;
      }

      // Normalize to first day of month.
      const normalizedPeriod = new Date(
        Date.UTC(
          period.getUTCFullYear(),
          period.getUTCMonth(),
          1,
        ),
      );

      // --------------------------------------------------------
      // DO NOT ALLOW BEFORE 2023
      // --------------------------------------------------------

      if (normalizedPeriod.getUTCFullYear() < 2023) {
        results.errors.push({
          row: rowNumber,
          employeeId,
          message: "Only payroll data from 2023 onwards is allowed.",
        });

        continue;
      }

      // --------------------------------------------------------
      // CHECK EMPLOYEE
      // --------------------------------------------------------

      const employee = await prisma.employee.findUnique({
        where: {
          employeeId,
        },
      });

      if (!employee) {
        results.errors.push({
          row: rowNumber,
          employeeId,
          message: "Employee does not exist in database.",
        });

        continue;
      }

      // --------------------------------------------------------
      // PAYROLL DATA
      // --------------------------------------------------------

      const payrollData = {
        basicSalary: numberValue(
          row.basic_salary ?? row.basicSalary,
        ),

        foodAllowance: numberValue(
          row.food_allowance ?? row.foodAllowance,
        ),

        otherAllowance: numberValue(
          row.other_allowance ?? row.otherAllowance,
        ),

        overtime: numberValue(
          row.overtime,
        ),

        bonus: numberValue(
          row.bonus,
        ),

        commission: numberValue(
          row.commission,
        ),

        otherEarnings: numberValue(
          row.other_earnings ?? row.otherEarnings,
        ),

        epfEmployee: numberValue(
          row.epf_employee ?? row.epfEmployee,
        ),

        socsoEmployee: numberValue(
          row.socso_employee ?? row.socsoEmployee,
        ),

        eisEmployee: numberValue(
          row.eis_employee ?? row.eisEmployee,
        ),

        pcb: numberValue(
          row.pcb,
        ),

        otherDeduction: numberValue(
          row.other_deduction ?? row.otherDeduction,
        ),

        epfEmployer: numberValue(
          row.epf_employer ?? row.epfEmployer,
        ),

        socsoEmployer: numberValue(
          row.socso_employer ?? row.socsoEmployer,
        ),

        eisEmployer: numberValue(
          row.eis_employer ?? row.eisEmployer,
        ),

        newIcNo:
          String(
            row.new_ic_no ??
            row.newIcNo ??
            employee.newIcNo ??
            "",
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
          row.remarks
            ? String(row.remarks)
            : null,
      };

      // --------------------------------------------------------
      // CHECK IF RECORD ALREADY EXISTS
      // --------------------------------------------------------

      const existing =
        await prisma.payrollRecord.findUnique({
          where: {
            employeeId_period: {
              employeeId,
              period: normalizedPeriod,
            },
          },
        });

      // --------------------------------------------------------
      // CREATE OR UPDATE
      // --------------------------------------------------------

      await prisma.payrollRecord.upsert({
        where: {
          employeeId_period: {
            employeeId,
            period: normalizedPeriod,
          },
        },

        update: payrollData,

        create: {
          employeeId,
          period: normalizedPeriod,
          ...payrollData,
        },
      });

      if (existing) {
        results.updated++;
      } else {
        results.imported++;
      }
    }

    res.json({
      ok: true,
      message: "Payroll import completed.",
      ...results,
    });
  } catch (error) {
    console.error("PAYROLL IMPORT ERROR:", error);

    res.status(500).json({
      ok: false,
      message: "Payroll import failed.",
      error: error.message,
    });
  }
});

// ============================================================
// DELETE PAYROLL RECORD
// ============================================================

app.delete("/api/admin/payroll/:id", async (req, res) => {
  try {
    await prisma.payrollRecord.delete({
      where: {
        id: req.params.id,
      },
    });

    res.json({
      ok: true,
      message: "Payroll record deleted.",
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      message: error.message,
    });
  }
});

// ============================================================
// SERVER
// ============================================================

const port = Number(process.env.PORT || 5000);

app.listen(port, () => {
  console.log(
    `Hasani Payroll API running on http://localhost:${port}`,
  );
});