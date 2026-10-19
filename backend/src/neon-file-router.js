// Opt-in authenticated Neon file endpoints. Mount only after existing JWT middleware.
// The caller must provide an authorization function enforcing employee/branch/role scope.
import express from "express";
import multer from "multer";
import { MAX_FILE_BYTES, storePayrollFile, getPayrollFile } from "./neon-file-store.js";

export function createNeonFileRouter({ db, authorizeEmployee }) {
  if (!db || typeof db.query !== "function") throw new TypeError("Database client required");
  if (typeof authorizeEmployee !== "function") throw new TypeError("Authorization callback required");
  const router = express.Router();
  const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_FILE_BYTES, files: 1 } });

  router.post("/:employeeId", upload.single("file"), async (req, res) => {
    try {
      const employeeId = req.params.employeeId;
      if (!await authorizeEmployee(req, employeeId, "write")) return res.sendStatus(403);
      if (!req.file) return res.status(400).json({ error: "File required" });
      const id = await storePayrollFile(db, {
        ownerEmployeeId: employeeId,
        bytes: req.file.buffer,
        contentType: req.file.mimetype,
      });
      return res.status(201).json({ id });
    } catch (error) {
      if (error instanceof TypeError || error instanceof RangeError) {
        return res.status(400).json({ error: error.message });
      }
      return res.sendStatus(500);
    }
  });

  router.get("/:employeeId/:fileId", async (req, res) => {
    try {
      const employeeId = req.params.employeeId;
      if (!await authorizeEmployee(req, employeeId, "read")) return res.sendStatus(403);
      const file = await getPayrollFile(db, { id: req.params.fileId, ownerEmployeeId: employeeId });
      if (!file) return res.sendStatus(404);
      res.set("Content-Type", file.content_type);
      res.set("Cache-Control", "private, no-store");
      res.set("X-Content-Type-Options", "nosniff");
      return res.send(file.file_bytes);
    } catch (error) {
      if (error instanceof TypeError) return res.sendStatus(400);
      return res.sendStatus(500);
    }
  });

  router.use((error, _req, res, next) => {
    if (error instanceof multer.MulterError) {
      return res.status(error.code === "LIMIT_FILE_SIZE" ? 413 : 400).json({ error: "Upload rejected" });
    }
    next(error);
  });
  return router;
}
