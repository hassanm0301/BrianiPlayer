#!/usr/bin/env python3
"""Validate planning-package structure, IDs, defaults and API references.

Requires Python 3.10+ and PyYAML. Optional openapi-spec-validator adds a
standards-schema check. This does NOT run Briani implementation tests.
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path
try:
    import yaml
except ImportError:
    raise SystemExit('Missing PyYAML. Install in a virtual environment: python -m pip install PyYAML')

ROOT=Path(__file__).resolve().parents[1]
errors:list[str]=[]
checks=0

def check(condition:bool,message:str)->None:
    global checks
    checks+=1
    if not condition:errors.append(message)

def read_json(path:str)->dict:
    try:return json.loads((ROOT/path).read_text(encoding='utf-8'))
    except (OSError,ValueError) as exc:
        errors.append(f'{path}: {exc}')
        return {}

required=['00_START_HERE.md','AGENTS.md','agents/EXECUTION_PROTOCOL.md','agents/WORKER_PROMPT.md','agents/HANDOFF_TEMPLATE.md','agents/CODEX_TEMPLATES.md','contracts/openapi.yaml','contracts/defaults.json','evidence/status.json','evidence/REPORT_TEMPLATE.md']
for file in required:check((ROOT/file).is_file(),f'Missing {file}')
specs=sorted((ROOT/'specs').glob('*.md'))
check([p.name[:2] for p in specs]==[f'{i:02d}' for i in range(1,15)],'Expected specifications 01–14 exactly once.')
ms=sorted((ROOT/'milestones').glob('M*.md'))
expected_m=[f'M{i:02d}' for i in range(12)]
check([p.name[:3] for p in ms]==expected_m,'Expected milestones M00–M11 exactly once.')
for p in ms:
    t=p.read_text()
    for h in ['## Required reading and ownership','## Bounded subagent assignments','## Ordered implementation tasks','## Acceptance and execution','## Deliverables','## Boundaries and continuation']:
        check(h in t,f'{p.name}: missing {h}')
    check(len(t.split())>=500,f'{p.name}: unexpectedly short work package.')
status=read_json('evidence/status.json')
check([m.get('id') for m in status.get('milestones',[])]==expected_m,'Status milestone sequence does not match work packages.')
for m in status.get('milestones',[]):check((ROOT/m.get('file','')).is_file(),f"Unknown milestone status file: {m.get('file')}")
check([t.get('id') for t in status.get('tests',[])]==[f'T{i:02d}' for i in range(1,33)],'Expected T01–T32 status entries.')
product=(ROOT/'specs/01_PRODUCT.md').read_text()
trace=(ROOT/'specs/13_TRACEABILITY.md').read_text()
tests=(ROOT/'specs/09_TEST_AND_RELEASE.md').read_text()
for i in range(1,27):
    key=f'R{i:02d}'
    check(f'| {key} |' in product,f'{key} missing from product table.')
    check(f'| {key} ' in trace,f'{key} missing from traceability.')
for i in range(1,33):check(f'| T{i:02d} |' in tests,f'T{i:02d} missing test definition.')
source=(ROOT/'specs/14_SOURCES_AND_LICENSING.md').read_text()
source_ids=set(re.findall(r'^### (S\d{2}) ',source,re.M))
check(source_ids=={f'S{i:02d}' for i in range(1,30)},'Expected primary sources S01–S29.')
for p in ROOT.rglob('*.md'):
    t=p.read_text()
    for sid in set(re.findall(r'\bS\d{2}\b',t)):check(sid in source_ids,f'{p.name}: undefined source {sid}.')
    for filename in re.findall(r'\b\d{2}_[A-Z_]+\.md\b',t):check((ROOT/'specs'/filename).exists() or (ROOT/filename).exists(),f'{p.name}: missing specification {filename}.')
defaults=read_json('contracts/defaults.json')
check(defaults.get('downloads',{}).get('sequential') is True,'Sequential default must be true.')
check(defaults.get('downloads',{}).get('seekAwarePrioritization') is False,'Seek reprioritization must be disabled.')
check(defaults.get('server',{}).get('runtime')=='net10.0','Runtime contract must be net10.0.')
check(defaults.get('playback',{}).get('ticketAbsoluteHours',0)*60>defaults.get('playback',{}).get('ticketFirstUseMinutes',0),'Long playback lifetime must exceed activation interval.')
check(defaults.get('playback',{}).get('copyBufferBytes',0)<=1024*1024,'Unexpectedly large HTTP copy buffer.')
try:
    api=yaml.safe_load((ROOT/'contracts/openapi.yaml').read_text())
except (OSError,yaml.YAMLError) as exc:
    errors.append(f'OpenAPI YAML parse failed: {exc}');api={}
check(api.get('openapi')=='3.0.3','Unexpected OpenAPI version.')
operation_ids=[]
for path,item in api.get('paths',{}).items():
    for method,op in item.items():
        if method not in {'get','post','put','patch','delete','head','options','trace'}:continue
        operation_ids.append(op.get('operationId'))
        names=set(re.findall(r'\{([^}]+)\}',path))
        supplied={x['name'] for x in op.get('parameters',[]) if x.get('in')=='path'}
        check(names==supplied,f'{method} {path}: path parameters do not match.')
        for x in op.get('parameters',[]):
            if x.get('in')=='path':check(x.get('required') is True,f'{path}: path parameter must be required.')
        check(bool(op.get('responses')),f'{method} {path}: missing responses.')
        check(op.get('security')!=[] or path.startswith(('/api/v1/auth/','/api/v1/bootstrap','/api/v1/server','/stream/','/healthz','/readyz')),f'{method} {path}: unexpected public operation.')
        if path.startswith('/stream/'):
            check(op.get('x-authentication')=='mandatory-scoped-path-ticket',f'{path}: playback ticket authentication not specified.')
check(None not in operation_ids and len(operation_ids)==len(set(operation_ids)),'Operation IDs must be present and unique.')

def walk(v,path='root'):
    if isinstance(v,dict):
        if '$ref' in v:
            target=v['$ref'];check(target.startswith('#/'),f'{path}: unexpected external reference {target}')
            if target.startswith('#/'):
                current=api
                try:
                    for key in target[2:].split('/'):current=current[key.replace('~1','/').replace('~0','~')]
                except (KeyError,TypeError):errors.append(f'{path}: unresolved reference {target}')
        if 'properties' in v:
            for key in v.get('required',[]):check(key in v['properties'],f'{path}: required unknown property {key}')
        for key,value in v.items():walk(value,f'{path}/{key}')
    elif isinstance(v,list):
        for i,value in enumerate(v):walk(value,f'{path}/{i}')
walk(api)
standards='not installed; structural checks only'
try:
    from openapi_spec_validator import validate
except ImportError:pass
else:
    try:validate(api);standards='passed'
    except Exception as exc:errors.append(f'OpenAPI standards validation: {exc}');standards='failed'
print(f'Plan structural checks: {checks}')
print(f'Specifications: {len(specs)}; milestones: {len(ms)}; operations: {len(operation_ids)}; schemas: {len(api.get("components",{}).get("schemas",{}))}')
print(f'Optional OpenAPI standards validation: {standards}')
print('This does not execute implementation tests T01–T32.')
if errors:
    for e in errors:print(f'ERROR: {e}',file=sys.stderr)
    raise SystemExit(1)
print('PASS: package structural consistency.')
