// Small process-local cache for read models only. Install the route middleware
// AFTER authentication/authorization; successful writes clear all read models.
export function createReadResponseCache({ttlMs=30_000,maxEntries=48,maxBytes=8*1024*1024,now=Date.now}={}) {
  const entries=new Map(), pending=new Map();
  let generation=0,bytes=0;
  function invalidate(){ generation++;entries.clear();bytes=0; }
  function forget(key){const entry=entries.get(key);if(entry){bytes-=entry.bytes;entries.delete(key);}}
  function writeInvalidation(req,res,next){
    if(!['GET','HEAD','OPTIONS'].includes(req.method)) {
      // Clear at both boundaries: reads made during a write must not survive it.
      invalidate();
      res.once('finish',()=>{if(res.statusCode>=200&&res.statusCode<400)invalidate();});
    }
    next();
  }
  async function middleware(req,res,next){
    res.set('Cache-Control','no-store');
    // Include the full verified identity and scope, never a client-provided role.
    const key=JSON.stringify([req.originalUrl,req.user,req.auth?.app_metadata]);
    let entry=entries.get(key);
    if(entry&&entry.expires>now())return res.type('json').send(entry.body);
    forget(key);
    const waiting=pending.get(key);
    if(waiting&&waiting.generation===generation){
      entry=await waiting.promise;
      if(entry&&entry.generation===generation&&entry.expires>now())return res.type('json').send(entry.body);
      return middleware(req,res,next);
    }
    if(pending.size>=maxEntries)return next();
    const startedGeneration=generation;
    let resolve;
    const token={generation:startedGeneration,promise:new Promise(done=>{resolve=done;})};
    pending.set(key,token);
    let finished=false;
    function complete(value){
      if(finished)return;
      finished=true;
      if(pending.get(key)===token)pending.delete(key);
      resolve(value);
    }
    const json=res.json;
    res.json=function(body){
      let cached=null;
      try{
        if(res.statusCode===200&&generation===startedGeneration){
          const serialized=JSON.stringify(body),size=Buffer.byteLength(serialized);
          if(size<=maxBytes){
            cached={body:serialized,bytes:size,generation,expires:now()+ttlMs};
            forget(key);
            while(entries.size&&(entries.size>=maxEntries||bytes+size>maxBytes))forget(entries.keys().next().value);
            entries.set(key,cached);bytes+=size;
          }
        }
        return json.call(this,body);
      }finally{complete(cached);}
    };
    res.once('finish',()=>complete(null));
    res.once('close',()=>complete(null));
    next();
  }
  return {middleware,writeInvalidation,invalidate};
}
