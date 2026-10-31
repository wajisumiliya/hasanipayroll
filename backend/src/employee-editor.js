// One parameterised data query instead of schema introspection + separate reads.
export function installEmployeeEditorApi(app,{authenticate,pool}) {
  app.get('/api/admin/employees/:employeeId/edit-data',authenticate,async(req,res)=>{
    const scope=req.auth?.app_metadata?.staff_scope;
    if(String(req.user?.role??'').toUpperCase()!=='ADMIN'||req.auth?.app_metadata?.is_reviewer||['attendance','requests'].includes(scope))
      return res.status(403).json({ok:false,message:'Administrator access required.'});
    const id=String(req.params.employeeId??'').trim().toUpperCase();
    if(!/^[A-Z0-9._-]{1,100}$/.test(id))return res.status(400).json({ok:false,message:'Invalid employee ID.'});
    try {
      const result=await pool.query(`SELECT to_jsonb(e) AS employee, to_jsonb(d) AS salary_defaults
        FROM public.employees e LEFT JOIN public.employee_salary_defaults d ON d.employee_id=e.employee_id
        WHERE UPPER(TRIM(e.employee_id))=$1 LIMIT 1`,[id]);
      const row=result.rows[0];
      if(!row)return res.status(404).json({ok:false,message:'Employee not found.'});
      const foreign=String(row.employee.address??'').toUpperCase().includes('FRN');
      if((scope==='local'&&foreign)||(scope==='foreign'&&!foreign))return res.status(403).json({ok:false,message:'Employee outside your staff scope.'});
      return res.json({ok:true,employee:row.employee,salary_defaults:row.salary_defaults??{}});
    } catch(error) {
      console.error('EMPLOYEE EDIT DATA ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Unable to load employee edit data. Please retry.'});
    }
  });
}
