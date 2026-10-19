// Read-only audit of remaining Supabase dependencies for the Neon cutover.
// Usage: node backend/scripts/audit-neon-cutover.mjs
import fs from "node:fs";
import path from "node:path";
const root = path.resolve(import.meta.dirname, "../..");
const categories = {
  database: /\.from\s*\(|\.rpc\s*\(|\.rest\b|PostgrestClient|SupabaseClient/g,
  auth: /\.auth\b|Supabase\.initialize|Supabase\.instance/g,
  realtime: /\.channel\s*\(|\.onPostgresChanges\s*\(|RealtimeChannel|\.removeChannel\s*\(/g,
  functions: /\.functions\b|functions\.invoke/g,
  storage: /\.storage\b|\.uploadBinary\s*\(|\.createSignedUrl\s*\(/g,
};
const permittedTemporary = new Set(["storage", "notifications"]);
const matches=[];
function scan(folder) {
  if (!fs.existsSync(folder)) return;
  for (const item of fs.readdirSync(folder,{withFileTypes:true})) {
    const full=path.join(folder,item.name);
    if(item.isDirectory()) {scan(full);continue;}
    if(!item.name.endsWith(".dart"))continue;
    const lines=fs.readFileSync(full,"utf8").split(/\r?\n/);
    lines.forEach((line,i)=>{
      for(const [category,re] of Object.entries(categories)){
        re.lastIndex=0;
        if(re.test(line))matches.push({file:path.relative(root,full).replaceAll("\\","/"),line:i+1,category,code:line.trim().slice(0,160)});
      }
    });
  }
}
scan(path.join(root,"lib"));
const result={status:"INCOMPLETE",policy:{database:"Neon via Render",auth:"Render and Neon",realtime:"Render",storage:"Supabase temporarily",notifications:"Supabase temporarily"},total:matches.length,byCategory:Object.fromEntries(Object.keys(categories).map(k=>[k,matches.filter(x=>x.category===k).length])),matches};
console.log(JSON.stringify(result,null,2));
// Strict mode blocks accidental declaration of migration completion.
if(process.argv.includes("--strict") && matches.some(x=>!permittedTemporary.has(x.category)))process.exitCode=1;
