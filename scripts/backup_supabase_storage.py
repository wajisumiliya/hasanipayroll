#!/usr/bin/env python3
"""Download every object from one Supabase Storage bucket for encrypted backup."""
import argparse, json, pathlib, urllib.parse, urllib.request

def request(url, key, data=None):
    headers={"Authorization":f"Bearer {key}","apikey":key}
    body=None
    if data is not None:
        body=json.dumps(data).encode()
        headers["Content-Type"]="application/json"
    req=urllib.request.Request(url,data=body,headers=headers,method="POST" if data is not None else "GET")
    return urllib.request.urlopen(req,timeout=60).read()

def list_dir(base,key,bucket,prefix=""):
    offset=0
    while True:
        payload={"prefix":prefix,"limit":1000,"offset":offset,"sortBy":{"column":"name","order":"asc"}}
        raw=request(f"{base}/storage/v1/object/list/{urllib.parse.quote(bucket,safe='')}",key,payload)
        rows=json.loads(raw)
        if not rows: break
        for row in rows:
            name=row.get("name")
            if not name: continue
            path=f"{prefix}/{name}".strip("/")
            # Folder placeholders have no object metadata.
            if row.get("id") is None:
                yield from list_dir(base,key,bucket,path)
            else:
                yield path
        if len(rows)<1000: break
        offset+=len(rows)

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--url",required=True); p.add_argument("--service-role-key",required=True)
    p.add_argument("--bucket",required=True); p.add_argument("--output",required=True)
    a=p.parse_args(); out=pathlib.Path(a.output); out.mkdir(parents=True,exist_ok=True)
    count=0
    for obj in list_dir(a.url.rstrip("/"),a.service_role_key,a.bucket):
        dest=out/pathlib.PurePosixPath(obj); dest.parent.mkdir(parents=True,exist_ok=True)
        quoted=urllib.parse.quote(obj,safe="/")
        dest.write_bytes(request(f"{a.url.rstrip('/')}/storage/v1/object/authenticated/{urllib.parse.quote(a.bucket,safe='')}/{quoted}",a.service_role_key))
        count+=1
    print(f"Backed up {count} storage objects.")

if __name__=="__main__": main()
