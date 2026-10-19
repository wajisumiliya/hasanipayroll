// Neon-backed binary storage primitives. Call only from authenticated API routes.
// This module does not create tables or modify production configuration.
import crypto from "node:crypto";

export const MAX_FILE_BYTES = 5 * 1024 * 1024;
const ALLOWED_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "application/pdf"]);

export function validatePayrollFile({ bytes, contentType }) {
  if (!Buffer.isBuffer(bytes) || bytes.length === 0 || bytes.length > MAX_FILE_BYTES) {
    throw new RangeError("File must be nonempty and no larger than 5 MiB");
  }
  if (!ALLOWED_TYPES.has(contentType)) {
    throw new TypeError("Unsupported file content type");
  }
  const jpg = bytes.length >= 3 && bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]));
  const png = bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const webp = bytes.length >= 12 && bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP";
  const pdf = bytes.length >= 5 && bytes.toString("ascii", 0, 5) === "%PDF-";
  const matches = { "image/jpeg": jpg, "image/png": png, "image/webp": webp, "application/pdf": pdf };
  if (!matches[contentType]) throw new TypeError("File signature does not match content type");
}

export async function storePayrollFile(db, { ownerEmployeeId, bytes, contentType }) {
  if (typeof ownerEmployeeId !== "string" || !ownerEmployeeId.trim()) {
    throw new TypeError("Employee identifier is required");
  }
  validatePayrollFile({ bytes, contentType });
  const id = crypto.randomUUID();
  await db.query(
    "INSERT INTO payroll_file_objects (id, owner_employee_id, content_type, file_bytes) VALUES ($1, $2, $3, $4)",
    [id, ownerEmployeeId.trim(), contentType, bytes],
  );
  return id;
}

export async function getPayrollFile(db, { id, ownerEmployeeId }) {
  if (typeof id !== "string" || !/^[0-9a-f-]{36}$/i.test(id)) throw new TypeError("Invalid file identifier");
  if (typeof ownerEmployeeId !== "string" || !ownerEmployeeId.trim()) throw new TypeError("Employee identifier is required");
  const { rows } = await db.query(
    "SELECT content_type, file_bytes FROM payroll_file_objects WHERE id = $1 AND owner_employee_id = $2",
    [id, ownerEmployeeId.trim()],
  );
  return rows[0] ?? null;
}
