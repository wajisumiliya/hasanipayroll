import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';

const root=path.resolve('build/module-browser');
const types={'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.json':'application/json'};
const staticServer=createServer(async(req,res)=>{
  const name=path.resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
  if(name!==root&&!name.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  try{const file=name===root?path.join(root,'index.html'):name;res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');res.end(await readFile(file));}
  catch{res.writeHead(404).end();}
});
await new Promise(resolve=>staticServer.listen(3001,'127.0.0.1',resolve));
const chrome=spawn(process.env.CHROME_BIN||'google-chrome',[
  '--headless=new','--no-sandbox','--disable-dev-shm-usage','--no-first-run',
  '--remote-debugging-port=9222',`--user-data-dir=/tmp/hasani-module-browser-${process.pid}`,
],{stdio:['ignore','ignore','pipe']});
let socket;
try{
  let page;
  for(let i=0;i<60;i++){
    try{const response=await fetch('http://127.0.0.1:9222/json/new?http://localhost:3001',{method:'PUT'});page=await response.json();break;}
    catch{await new Promise(resolve=>setTimeout(resolve,250));}
  }
  assert.ok(page?.webSocketDebuggerUrl,'Chrome did not start');
  socket=new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
  let nextId=0;const pending=new Map();
  socket.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.id){const callback=pending.get(message.id);pending.delete(message.id);callback?.(message);}});
  const command=(method,params)=>new Promise(resolve=>{const id=++nextId;pending.set(id,resolve);socket.send(JSON.stringify({id,method,params}));});
  let result;
  for(let i=0;i<180;i++){
    const response=await command('Runtime.evaluate',{expression:"document.body?.getAttribute('data-module-result')",returnByValue:true});
    const value=response.result?.result?.value;
    if(value&&value!=='running'){result=JSON.parse(value);break;}
    await new Promise(resolve=>setTimeout(resolve,1000));
  }
  assert.ok(result,'Browser module checks timed out');
  console.log(JSON.stringify(result,null,2));
  assert.equal(result.ok,true,'Browser module flow failed');
}finally{
  socket?.close();chrome.kill('SIGTERM');await new Promise(resolve=>staticServer.close(resolve));
}
