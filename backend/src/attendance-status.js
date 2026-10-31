export function normalizeAttendanceWrite(row) {
  if(!row||typeof row!=='object')return row;
  const status=String(row.status??'').trim().toUpperCase();
  if(status==='PH-GUNTI')return {...row,status:'PH-GANTI'};
  if(status==='UL'||status==='UL-UNPAID')return {...row,status:'UL-UNPAID',is_unpaid:true};
  return row;
}
