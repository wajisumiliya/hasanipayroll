import assert from 'node:assert/strict';
import { readFile,readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test from 'node:test';

test('application source cannot initialize or call the removed Supabase SDK',async()=>{
  const root=fileURLToPath(new URL('../../lib/',import.meta.url));
  async function scan(dir){
    for(const entry of await readdir(dir,{withFileTypes:true})){
      const filename=path.join(dir,entry.name);
      if(entry.isDirectory()) await scan(filename);
      else if(filename.endsWith('.dart')){
        const source=await readFile(filename,'utf8');
        assert.doesNotMatch(source,/package:supabase_flutter|\bSupabase\.(?:initialize|instance)|SupabaseService\.client|NEON_DATA_API_URL|SUPABASE_URL|SUPABASE_ANON_KEY/,
          `Legacy provider call in ${path.relative(root,filename)}`);
        if(path.basename(filename)!=='neon_api.dart') {
          assert.doesNotMatch(source,/\bPostgrestClient\(/,
            `Database clients must use the shared backend JWT endpoint: ${path.relative(root,filename)}`);
        }
      }
    }
  }
  await scan(root);
});
