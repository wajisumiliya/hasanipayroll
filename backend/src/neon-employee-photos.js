import express from 'express';
import { withDatabaseIdentity, claimsForRequest } from './data-api.js';

export const MAX_PHOTO_BYTES = 512 * 1024;
export function validatePhoto(bytes, contentType) {
  if (!Buffer.isBuffer(bytes) || !bytes.length || bytes.length > MAX_PHOTO_BYTES) return false;
  if (contentType === 'image/jpeg') return bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (contentType === 'image/png') return bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
  if (contentType === 'image/webp') return bytes.length >= 12 && bytes.toString('ascii',0,4) === 'RIFF' && bytes.toString('ascii',8,12) === 'WEBP';
  return false;
}

export function installNeonPhotoApi(app, { pool, authenticate, visibleEmployee = async (req, id) => {
  if (req.auth?.app_metadata?.is_reviewer) return false;
  const result = await withDatabaseIdentity(pool, claimsForRequest(req), client =>
    client.query('SELECT employee_id FROM public.employees WHERE employee_id=$1', [id]));
  return result.rowCount > 0;
} }) {
  const route = '/api/employee-photos/:employeeId';
  async function authorize(req, res, next) {
    res.set('Cache-Control', 'private, no-store');
    const id = String(req.params.employeeId || '').trim();
    if (!/^[A-Za-z0-9_-]{1,80}$/.test(id)) return res.status(400).json({ok:false,message:'Invalid employee ID.'});
    if (req.method !== 'GET' && req.method !== 'HEAD' &&
        (String(req.user.role).toUpperCase() !== 'ADMIN' ||
        ['attendance','requests'].includes(req.auth?.app_metadata?.staff_scope))) {
      return res.status(403).json({ok:false,message:'Administrator access required.'});
    }
    try {
      if (!await visibleEmployee(req, id)) return res.status(403).json({ok:false,message:'Access denied.'});
      req.photoEmployeeId = id;
      next();
    } catch { return res.status(503).json({ok:false,message:'Unable to authorize photo access.'}); }
  }
  app.get(route, authenticate, authorize, async (req,res) => {
    try {
      const result = await pool.query('SELECT content_type,photo_bytes FROM app_private.employee_photos WHERE employee_id=$1',[req.photoEmployeeId]);
      if (!result.rowCount) return res.status(404).json({ok:false,message:'Photo not found.'});
      const photo = result.rows[0];
      res.set('X-Content-Type-Options','nosniff');
      res.set('Content-Type',photo.content_type);
      return res.send(photo.photo_bytes);
    } catch { return res.status(503).json({ok:false,message:'Unable to load employee photo.'}); }
  });
  app.put(route, authenticate, authorize, express.raw({type:()=>true,limit:MAX_PHOTO_BYTES}), async (req,res) => {
    const contentType = String(req.get('Content-Type') || '').split(';')[0].toLowerCase();
    if (!validatePhoto(req.body,contentType)) return res.status(400).json({ok:false,message:'Use a JPEG, PNG or WebP photo of 512 KB or smaller.'});
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const reference = 'neon-photo/' + req.photoEmployeeId;
      const employee = await client.query('UPDATE public.employees SET photo_url=$2 WHERE employee_id=$1 RETURNING employee_id',[req.photoEmployeeId,reference]);
      if (!employee.rowCount) throw new Error('Employee no longer exists');
      await client.query(`INSERT INTO app_private.employee_photos(employee_id,content_type,photo_bytes) VALUES ($1,$2,$3)
        ON CONFLICT(employee_id) DO UPDATE SET content_type=EXCLUDED.content_type,photo_bytes=EXCLUDED.photo_bytes,updated_at=now()`,[req.photoEmployeeId,contentType,req.body]);
      await client.query('COMMIT');
      return res.json({ok:true,photoUrl:reference});
    } catch {
      await client.query('ROLLBACK');
      return res.status(503).json({ok:false,message:'Unable to save employee photo.'});
    } finally { client.release(); }
  });
  app.delete(route, authenticate, authorize, async (req,res) => {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('UPDATE public.employees SET photo_url=NULL WHERE employee_id=$1',[req.photoEmployeeId]);
      await client.query('DELETE FROM app_private.employee_photos WHERE employee_id=$1',[req.photoEmployeeId]);
      await client.query('COMMIT');
      return res.json({ok:true});
    } catch {
      await client.query('ROLLBACK');
      return res.status(503).json({ok:false,message:'Unable to remove employee photo.'});
    } finally { client.release(); }
  });
  app.use('/api/employee-photos', (error,req,res,next) => {
    if (error.type === 'entity.too.large') return res.status(413).json({ok:false,message:'Photo must be 512 KB or smaller.'});
    next(error);
  });
}
