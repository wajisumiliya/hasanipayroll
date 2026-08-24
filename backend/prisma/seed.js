import "dotenv/config";
import bcrypt from "bcryptjs";
import pg from "pg";
import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const { Pool } = pg;

// PostgreSQL connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const adapter = new PrismaPg(pool);

const prisma = new PrismaClient({
  adapter,
});

// ============================================================
// EMPLOYEES
// ============================================================

const employees = [
  {
    employeeId: "EMP00125",
    name: "MOHAMED WAJEETHU ALI",
    designation: "STAFF",
    department: "GENERAL",
    email: "employee@example.com",
    newIcNo: "-",
    bankCode: "RHBMY",
    bankAccount: "10206900485316",
  },
  {
    employeeId: "EMP00126",
    name: "NUR AIN BINTI AZMAN",
    designation: "EXECUTIVE",
    department: "FINANCE",
    email: "ain@example.com",
    newIcNo: "-",
    bankCode: "MAYBANK",
    bankAccount: "1144556677",
  },
  {
    employeeId: "EMP00127",
    name: "MOHD FIRDAUS",
    designation: "SUPERVISOR",
    department: "SALES",
    email: "firdaus@example.com",
    newIcNo: "-",
    bankCode: "CIMB",
    bankAccount: "2233445566",
  },
  {
    employeeId: "EMP00128",
    name: "SITI NURUL",
    designation: "ASSISTANT",
    department: "OPERATIONS",
    email: "siti@example.com",
    newIcNo: "-",
    bankCode: "RHBMY",
    bankAccount: "3344556677",
  },
  {
    employeeId: "EMP00129",
    name: "AHMAD HAKIM",
    designation: "STAFF",
    department: "WAREHOUSE",
    email: "hakim@example.com",
    newIcNo: "-",
    bankCode: "PUBLIC",
    bankAccount: "4455667788",
  },
  {
    employeeId: "EMP00130",
    name: "NADIA FARHANA",
    designation: "EXECUTIVE",
    department: "HR",
    email: "nadia@example.com",
    newIcNo: "-",
    bankCode: "MAYBANK",
    bankAccount: "5566778899",
  },
  {
    employeeId: "EMP00131",
    name: "ZULKIFLI",
    designation: "STAFF",
    department: "LOGISTICS",
    email: "zul@example.com",
    newIcNo: "-",
    bankCode: "CIMB",
    bankAccount: "6677889900",
  },
  {
    employeeId: "EMP00132",
    name: "FATIMAH",
    designation: "ASSISTANT",
    department: "ADMIN",
    email: "fatimah@example.com",
    newIcNo: "-",
    bankCode: "RHBMY",
    bankAccount: "7788990011",
  },
];

// ============================================================
// MAIN SEED
// ============================================================

async function main() {
  console.log("=================================");
  console.log("Starting Hasani Payroll seed...");
  console.log("=================================");

  // ----------------------------------------------------------
  // ADMIN
  // ----------------------------------------------------------

  const adminPassword = await bcrypt.hash("admin123", 12);

  await prisma.user.upsert({
    where: {
      email: "admin@hasani.local",
    },
    update: {
      passwordHash: adminPassword,
      role: "ADMIN",
      isActive: true,
    },
    create: {
      email: "admin@hasani.local",
      passwordHash: adminPassword,
      role: "ADMIN",
      isActive: true,
    },
  });

  console.log("✓ Admin created");

  // ----------------------------------------------------------
  // EMPLOYEES
  // ----------------------------------------------------------

  const employeePassword = await bcrypt.hash("demo123", 12);

  for (const employeeData of employees) {
    const employee = await prisma.employee.upsert({
      where: {
        employeeId: employeeData.employeeId,
      },

      update: employeeData,

      create: employeeData,
    });

    await prisma.user.upsert({
      where: {
        employeeId: employee.employeeId,
      },

      update: {
        passwordHash: employeePassword,
        role: "EMPLOYEE",
        isActive: true,
      },

      create: {
        employeeId: employee.employeeId,
        email: employee.email,
        passwordHash: employeePassword,
        role: "EMPLOYEE",
        isActive: true,
      },
    });

    console.log(`✓ Employee: ${employee.employeeId}`);
  }

  // ==========================================================
  // IMPORTANT
  // NO FAKE PAYROLL DATA IS GENERATED HERE
  //
  // Payroll must be imported from your real CSV/database.
  // Your existing payroll records will NOT be deleted.
  // ==========================================================

  console.log("");
  console.log("=================================");
  console.log("EMPLOYEE SETUP COMPLETED");
  console.log("=================================");
  console.log("");

  console.log("Payroll data was NOT generated.");
  console.log("Import real payroll records from 2023 onwards.");

  console.log("");
  console.log("Admin Login:");
  console.log("admin@hasani.local");
  console.log("Password: admin123");

  console.log("");
  console.log("Employee Login:");
  console.log("EMP00125");
  console.log("Password: demo123");

  console.log("");
  console.log("=================================");
  console.log("SEED COMPLETED SUCCESSFULLY");
  console.log("=================================");
}

// ============================================================
// RUN
// ============================================================

main()
  .catch((error) => {
    console.error("");
    console.error("SEED FAILED:");
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });