#!/usr/bin/env python3
"""Fetch only the locked OpenAPI generator and verify it before use."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import urllib.request

ROOT=Path(__file__).resolve().parents[2]

def bootstrap():
    pin=json.loads((ROOT/'toolchain.lock.json').read_text())['openapiGenerator']
    target=ROOT/'.tools/openapi'/f"openapi-generator-cli-{pin['version']}.jar"
    expected=pin['sha256']
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()==expected:
        print('Pinned generator already verified');return
    target.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=target.parent,delete=False) as out:
        temporary=Path(out.name)
        try:
            request=urllib.request.Request(pin['url'],headers={'User-Agent':'Briani-build/1'})
            with urllib.request.urlopen(request,timeout=60) as response:
                digest=hashlib.sha256();length=0
                while data:=response.read(65536):
                    length+=len(data)
                    if length>64*1024*1024:raise RuntimeError('Generator exceeds bounded download size')
                    digest.update(data);out.write(data)
            if digest.hexdigest()!=expected:raise RuntimeError('Generator checksum mismatch')
            out.flush();os.fsync(out.fileno());temporary.replace(target)
        finally:temporary.unlink(missing_ok=True)
    print('Pinned generator downloaded and verified')

if __name__=='__main__':bootstrap()
