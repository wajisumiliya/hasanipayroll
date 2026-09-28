import "dotenv/config";
import bcrypt from "bcryptjs";
import pg from "pg";
import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// Development-only seed identities. Keep all personal, payroll, identity and
// banking data out of source control.
const employees = [
  {
    employeeId: "DEMO001",
    name: "DEMO EMPLOYEE ONE",
    designation: "STAFF",
    department: "GENERAL",
    email: "demo.employee1@example.invalid",
    newIcNo: "-",
    bankCode: "DEMO",
    bankAccount: "000000000000",
  },
  {
    employeeId: "DEMO002",
    name: "DEMO EMPLOYEE TWO",
    designation: "EXECUTIVE",
    department: "FINANCE",
    email: "demo.employee2@example.invalid",
    newIcNo: "-",
    bankCode: "DEMO",
    bankAccount: "000000000001",
  },
];

async function main() {
  if (process.env.ALLOW_DEMO_SEED !== "true") {
    throw new Error(
      "Demo seed is disabled. Set ALLOW_DEMO_SEED=true only for a non-production database.",
    );
  }
  if (String(process.env.NODE_ENV || "").toLowerCase() === "production") {
    throw new Error("Refusing to run demo seed in NODE_ENV=production.");
  }

  const adminPlainPassword = String(process.env.ADMIN_PASSWORD || "");
  const employeePlainPassword = String(process.env.SEED_EMPLOYEE_PASSWORD || "");
  if (adminPlainPassword.length < 12 || employeePlainPassword.length < 12) {
    throw new Error(
      "ADMIN_PASSWORD and SEED_EMPLOYEE_PASSWORD must each contain at least 12 characters.",
    );
  }

  const adminPassword = await bcrypt.hash(adminPlainPassword, 12);
  await prisma.user.upsert({
    where: { email: "admin@example.invalid" },
    update: { passwordHash: adminPassword, role: "ADMIN", isActive: true },
    create: {
      email: "admin@example.invalid",
      passwordHash: adminPassword,
      role: "ADMIN",
      isActive: true,
    },
  });

  const employeePassword = await bcrypt.hash(employeePlainPassword, 12);
  for (const employeeData of employees) {
    const employee = await prisma.employee.upsert({
      where: { employeeId: employeeData.employeeId },
      update: employeeData,
      create: employeeData,
    });
    await prisma.user.upsert({
      where: { employeeId: employee.employeeId },
      update: { passwordHash: employeePassword, role: "EMPLOYEE", isActive: true },
      create: {
        employeeId: employee.employeeId,
        email: employee.email,
        passwordHash: employeePassword,
        role: "EMPLOYEE",
        isActive: true,
      },
    });
  }

  console.log("Demo seed completed. No real payroll data was generated.");
}

main()
  .catch((error) => {
    console.error("SEED FAILED:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
