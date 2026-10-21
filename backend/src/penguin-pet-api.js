// Employee-only, server-time pet progression; no payroll or crystal mutations.
export function installPenguinPetApi(app,{pool,authenticate}) {
 const route='/api/employee/penguin';
 const employeeId=req => {
  if (String(req.user?.role||'').toLowerCase()!=='employee' || req.auth?.app_metadata?.is_reviewer) return null;
  return String(req.user?.employeeId||req.user?.employee_id||req.auth?.app_metadata?.employee_id||'').trim() || null;
 };
 const view=row=>{
  const days=Math.max(0,Math.floor((Date.now()-new Date(row.adopted_at).getTime())/86400000));
  const stage=days<3?'egg':days<15?'chick':days<45?'juvenile':'adult';
  const recently=(v)=>v && Date.now()-new Date(v).getTime()<86400000;
  return {nickname:row.nickname,adoptedAt:row.adopted_at,ageDays:days,stage,
   fedToday:!!recently(row.last_fed_at),playedToday:!!recently(row.last_played_at),
   nextFeedAt:row.last_fed_at?new Date(new Date(row.last_fed_at).getTime()+86400000).toISOString():null,
   nextPlayAt:row.last_played_at?new Date(new Date(row.last_played_at).getTime()+86400000).toISOString():null};
 };
 async function handler(req,res,action) {
  const id=employeeId(req);
  if(!id) return res.status(403).json({ok:false,message:'Employee access required'});
  const client=await pool.connect();
  try {
   await client.query('BEGIN');
   // Serialize concurrent requests for this employee.
   const employee=await client.query('SELECT employee_id FROM public.employees WHERE employee_id=$1 FOR UPDATE',[id]);
   if(!employee.rowCount){await client.query('ROLLBACK');return res.status(403).json({ok:false,message:'Employee unavailable'});}
   await client.query('INSERT INTO app_private.employee_penguin_pets(employee_id) VALUES($1) ON CONFLICT DO NOTHING',[id]);
   if(action){
    const field=action==='feed'?'last_fed_at':'last_played_at';
    await client.query(`UPDATE app_private.employee_penguin_pets SET ${field}=now(),updated_at=now() WHERE employee_id=$1 AND (${field} IS NULL OR ${field}<=now()-interval '24 hours')`,[id]);
   }
   const result=await client.query('SELECT * FROM app_private.employee_penguin_pets WHERE employee_id=$1',[id]);
   await client.query('COMMIT');
   return res.set('Cache-Control','no-store').json({ok:true,pet:view(result.rows[0])});
  } catch(e) {
   await client.query('ROLLBACK').catch(()=>{});
   console.error('PENGUIN PET ERROR',e.code||'unavailable');
   return res.status(503).json({ok:false,message:'Penguin pet temporarily unavailable'});
  } finally {client.release();}
 }
 app.get(route,authenticate,(req,res)=>handler(req,res,null));
 app.post(route+'/feed',authenticate,(req,res)=>handler(req,res,'feed'));
 app.post(route+'/play',authenticate,(req,res)=>handler(req,res,'play'));
}
