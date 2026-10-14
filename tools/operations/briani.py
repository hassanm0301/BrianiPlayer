#!/usr/bin/env python3
"""Safe host-side Docker Compose operations for Briani."""
from __future__ import annotations
import argparse, ctypes, getpass, hashlib, ipaddress, json, os, platform, re, secrets, shutil, signal, subprocess, sys, time, urllib.parse, urllib.request, http.cookiejar
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

ROOT = Path(__file__).resolve().parents[2]
COMPOSE = ROOT / 'infra/compose/compose.yaml'
ADMIN = ROOT / 'infra/compose/compose.admin.yaml'
SERVICES = ('briani', 'qbittorrent', 'prowlarr')
ENV_KEYS = ('BRIANI_EGRESS_IMAGE','BRIANI_IMAGE','BRIANI_LOCAL_IMAGE','BRIANI_STATE','BRIANI_DATA','BRIANI_BIND','BRIANI_UID','BRIANI_GID','BRIANI_HOSTS')

class OpsError(Exception): pass

def require_memory_limits(project: Path):
    result=run(['docker','info','--format','{{json .MemoryLimit}}'],cwd=project,capture=True)
    if result.stdout.strip() != 'true':
        raise OpsError('Docker cannot enforce container memory limits on this host; enable the kernel/cgroup memory controller before deploying. No host configuration was changed.')

def kernel_containment_query():
    if platform.system()!='Linux' or platform.machine().lower() not in ('x86_64','amd64','aarch64','arm64'):
        raise OpsError('64-bit Linux amd64/arm64 is required')
    libc=ctypes.CDLL(None,use_errno=True);libc.syscall.restype=ctypes.c_long
    values={}
    for label,flag in (('abi',1),('errata',2)):
        ctypes.set_errno(0)
        values[label]=libc.syscall(ctypes.c_long(444),ctypes.c_void_p(),ctypes.c_size_t(0),ctypes.c_uint(flag))
        values[label+'Errno']=ctypes.get_errno()
    return values

def require_host_capabilities(project: Path):
    failures=[]
    try:require_memory_limits(project)
    except OpsError as error:failures.append(str(error))
    capabilities=kernel_containment_query()
    if capabilities['abi']<2 or capabilities['errata']<0 or capabilities['errata']&4==0:
        failures.append('The kernel lacks the Landlock ABI/erratum required for filesystem containment. Use a compatible kernel with Landlock enabled; this tool never changes kernel or boot settings.')
    if failures:raise OpsError(' '.join(failures))

def run(argv: Sequence[str], *, cwd: Path, env: dict[str,str] | None = None, capture: bool = False):
    try:
        p = subprocess.run(list(map(str, argv)), cwd=cwd, env=env, text=True,
                           stdout=subprocess.PIPE if capture else None,
                           stderr=subprocess.PIPE if capture else None, check=False)
    except OSError as e:
        raise OpsError(f'cannot run {argv[0]}: {e}') from e
    if p.returncode:
        # captured upstream output may contain temporary credentials; never echo it.
        if capture: raise OpsError(f"command failed ({p.returncode}): {Path(argv[0]).name} {' '.join(map(str,argv[1:]))}")
        raise OpsError(f"command failed ({p.returncode}): {' '.join(map(str,argv))}")
    return p

def parse_env(path: Path) -> dict[str,str]:
    vals={}
    if not path.exists(): return vals
    for line in path.read_text().splitlines():
        line=line.strip()
        if not line or line.startswith('#'): continue
        if '=' not in line: raise OpsError(f'invalid .env line in {path.name}')
        k,v=line.split('=',1)
        if not re.fullmatch(r'[A-Z][A-Z0-9_]*',k) or k not in ENV_KEYS: raise OpsError(f'unsupported .env key: {k}')
        if '\n' in v or '\r' in v: raise OpsError('invalid newline in .env value')
        vals[k]=v
    return vals

def write_env(path: Path, vals: dict[str,str]):
    payload=''.join(f'{k}={vals[k]}\n' for k in ENV_KEYS if k in vals)
    tmp=path.with_suffix('.env.tmp'); tmp.write_text(payload); os.chmod(tmp,0o600); tmp.replace(path)

def inside(a: Path,b: Path) -> bool:
    try: a.relative_to(b); return True
    except ValueError: return False

def valid_path(p: Path, label: str, *, create=False):
    if not p.is_absolute(): raise OpsError(f'{label} must be an absolute path')
    if any(c in str(p) for c in (':','#','\n','\r')): raise OpsError(f'{label} path contains a character unsafe in Compose volume syntax')
    if p == Path('/') or p.resolve() == Path('/'): raise OpsError(f'{label} cannot be /')
    if p.is_symlink(): raise OpsError(f'{label} cannot be a symlink')
    if create: p.mkdir(parents=True,exist_ok=True,mode=0o700)
    resolved=p.resolve(strict=True)
    if not resolved.is_dir(): raise OpsError(f'{label} must be a directory')
    if not os.access(resolved,os.W_OK|os.X_OK): raise OpsError(f'{label} is not writable/searchable by this user')
    return resolved

def require_mounted_parent(p:Path,label:str):
    """Require the selected target to be on a non-root mounted filesystem."""
    probe=p if p.exists() else p.parent
    probe=probe.resolve()
    while probe!=Path('/'):
        if os.path.ismount(probe): return
        probe=probe.parent
    raise OpsError(f'{label} must be on an already mounted non-root filesystem; refusing to create a directory on a missing mount')

def compose(project: Path, args: Sequence[str], env: dict[str,str] | None=None, *, admin=False, capture=False):
    # The repository Compose file has a default top-level project name. Always
    # override it from the private project directory so restore/rollback drills
    # cannot recreate or stop an unrelated deployment with the same default.
    resolved=project.resolve()
    slug=re.sub(r'[^a-z0-9_-]+','-',resolved.name.lower()).strip('-') or 'deployment'
    identity=hashlib.sha256(str(resolved).encode()).hexdigest()[:10]
    cmd=['docker','compose','--project-name',f'briani-{slug[:24]}-{identity}','-f',str(COMPOSE)]
    if admin: cmd += ['-f',str(ADMIN)]
    cmd += ['--project-directory',str(project),'--env-file',str(project/'.env')]
    cmd += list(args)
    return run(cmd,cwd=project,env=env,capture=capture)

def local_image_record(service:dict):
    if platform.machine().lower() in ('aarch64','arm64'):
        native=service.get('nativeArm64')
        if not isinstance(native,dict):raise OpsError('audited local ARM64 image record is missing')
        return native
    return service

def validate_image_lock(image:str, *, local=False, allow_history=True):
    lock_path=ROOT/'images.lock.json'
    toolchain=json.loads((ROOT/'toolchain.lock.json').read_text())
    if not lock_path.is_file(): raise OpsError('root images.lock.json is required before operating a deployment')
    lock=json.loads(lock_path.read_text())
    if lock.get('version')!=1 or not isinstance(lock.get('services'),dict): raise OpsError('unsupported images.lock.json format')
    services=lock['services']
    for key,toolkey in (('qbittorrent','qBittorrent'),('prowlarr','Prowlarr')):
        reference=services.get(key,{}).get('reference')
        if reference != toolchain.get('images',{}).get(toolkey,{}).get('reference'):
            raise OpsError(f'images.lock.json {key} reference does not match verified toolchain.lock.json')
        if reference not in COMPOSE.read_text(encoding='utf-8'):
            raise OpsError(f'Compose file does not use the locked {key} image reference')
    briani=services.get('briani',{})
    accepted = [briani.get('reference')] + (briani.get('acceptedReferences', []) if allow_history else [])
    if image in accepted and re.fullmatch(r'.+@sha256:[0-9a-f]{64}',image): return
    if local:
        briani=local_image_record(briani)
        tag=briani.get('localTag','briani-server:dev')
        expected=briani.get('localImageId')
        if not tag or not expected or image != tag or not re.fullmatch(r'sha256:[0-9a-f]{64}',expected):
            raise OpsError('local Briani image must match the tag and exact image ID in images.lock.json')
        actual=run(['docker','image','inspect','--format={{.Id}}',image],cwd=ROOT,capture=True).stdout.strip()
        if actual not in {expected,briani.get('runtimeConfigDigest')}: raise OpsError('local Briani image ID does not match images.lock.json')
        return
    raise OpsError('Briani image must match the audited digest in images.lock.json; use --local-image only for the exact locked local image')

def guard_reference(local:bool) -> str:
    lock=json.loads((ROOT/'images.lock.json').read_text()).get('services',{}).get('torrent-egress-guard',{})
    if local:lock=local_image_record(lock)
    ref=lock.get('localTag') if local else lock.get('reference')
    if not ref: raise OpsError('the audited namespace firewall image is missing from images.lock.json')
    if local:
        actual=run(['docker','image','inspect','--format={{.Id}}',ref],cwd=ROOT,capture=True).stdout.strip()
        if actual not in {lock.get('localImageId'),lock.get('runtimeConfigDigest')}: raise OpsError('namespace firewall local image ID does not match images.lock.json')
    elif not re.fullmatch(r'.+@sha256:[0-9a-f]{64}',ref): raise OpsError('namespace firewall image must use an audited digest')
    return ref

def context(project: Path):
    env=parse_env(project/'.env')
    if not env: raise OpsError(f'missing or empty {project}/.env; run init first')
    for key in ('BRIANI_IMAGE','BRIANI_STATE','BRIANI_DATA','BRIANI_BIND','BRIANI_UID','BRIANI_GID'):
        if not env.get(key): raise OpsError(f'missing required .env value {key}')
    local=env.get('BRIANI_LOCAL_IMAGE','false').lower()=='true'
    if env.get('BRIANI_LOCAL_IMAGE','false').lower() not in ('true','false'): raise OpsError('BRIANI_LOCAL_IMAGE must be true or false')
    if not local and not re.fullmatch(r'.+@sha256:[0-9a-f]{64}',env['BRIANI_IMAGE']): raise OpsError('BRIANI_IMAGE must be pinned by sha256 digest')
    validate_image_lock(env['BRIANI_IMAGE'],local=local)
    if env.get('BRIANI_EGRESS_IMAGE') != guard_reference(local): raise OpsError('deployment namespace firewall reference does not match the audited image')
    for k in ('BRIANI_STATE','BRIANI_DATA'):
        p=Path(env[k]);
        if not p.is_absolute(): raise OpsError(f'{k} must be absolute')
        if p.is_symlink(): raise OpsError(f'{k} cannot be a symlink')
        require_mounted_parent(p,k)
        valid_path(p,k)
    data=Path(env['BRIANI_DATA']).resolve(); state=Path(env['BRIANI_STATE']).resolve()
    if data==state or inside(data,state) or inside(state,data): raise OpsError('data and state paths overlap')
    uid,gid=int(env['BRIANI_UID']),int(env['BRIANI_GID'])
    if uid<1 or gid<1: raise OpsError('deployment UID/GID must be positive and non-root')
    if uid!=os.geteuid() or gid!=os.getegid(): raise OpsError('run operations as the UID/GID recorded in .env')
    try: ipaddress.IPv4Address(env['BRIANI_BIND'])
    except ipaddress.AddressValueError as e: raise OpsError('BRIANI_BIND must be an explicit IPv4 address') from e
    hosts=env.get('BRIANI_HOSTS','').split(';')
    if not hosts or any(not re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?',host) for host in hosts): raise OpsError('BRIANI_HOSTS contains an invalid host name')
    if state.stat().st_mode & 0o077: raise OpsError('state directory must not be accessible by group or other users')
    for service in SERVICES:
        child=state/service
        if child.is_symlink() or not child.is_dir() or child.stat().st_mode & 0o077: raise OpsError(f'missing or unsafe service state directory: {child}')
    secret_dir=state/'secrets'
    if secret_dir.is_symlink() or not secret_dir.is_dir() or secret_dir.stat().st_mode & 0o077: raise OpsError('missing or unsafe secrets directory')
    return env

def project_directory(path:Path):
    if path.is_symlink(): raise OpsError('project directory cannot be a symlink')
    resolved=path.resolve()
    if not resolved.is_dir(): raise OpsError(f'project directory does not exist: {resolved}')
    return resolved

def host_validate(data: Path,state: Path,uid:int,gid:int,minimum:int):
    if platform.system()!='Linux': raise OpsError('production server operations require 64-bit Linux')
    machine=platform.machine().lower()
    if machine not in ('aarch64','arm64','x86_64','amd64'): raise OpsError(f'unsupported architecture: {machine}')
    if sys.maxsize < 2**32: raise OpsError('64-bit Python is required')
    require_mounted_parent(data,'data'); require_mounted_parent(state,'state')
    data=valid_path(data,'data',create=True); state=valid_path(state,'state',create=True)
    if data==state or inside(data,state) or inside(state,data): raise OpsError('data and state paths must not overlap')
    if data == Path('/srv') or state == Path('/srv'): raise OpsError('choose dedicated directories below the mount, not the mount root')
    for p,label in ((data,'data'),(state,'state')):
        usage=shutil.disk_usage(p)
        if usage.free < minimum: raise OpsError(f'{label} has {usage.free} free bytes; requires at least {minimum}')
    for p,label in ((data,'data'),(state,'state')):
        probe=p/f'.briani-write-check-{secrets.token_hex(6)}'
        try: probe.touch(mode=0o600); probe.unlink()
        except OSError as e: raise OpsError(f'{label} mount is not writable: {e}') from e
    if uid<1 or gid<1: raise OpsError('UID and GID must be explicit positive host IDs')
    if uid != os.geteuid() or gid != os.getegid():
        raise OpsError('run init as the explicitly selected UID/GID; this tool never chowns or broadens host permissions')
    return data,state

def command_init(a):
    if a.project.is_symlink(): raise OpsError('project directory cannot be a symlink')
    project=a.project.resolve(); project.mkdir(parents=True,exist_ok=True)
    env_path=project/'.env'
    if env_path.exists() and not a.replace: raise OpsError(f'{env_path} already exists; preserve it or pass --replace')
    data,state=host_validate(Path(a.data),Path(a.state),a.uid,a.gid,a.minimum_free)
    if data==project or state==project or inside(data,project) or inside(state,project) or inside(project,data) or inside(project,state): raise OpsError('project directory must not contain or overlap data/state')
    if not a.local_image and not re.fullmatch(r'.+@sha256:[0-9a-f]{64}',a.image): raise OpsError('--image must be a repository reference pinned by sha256 digest')
    validate_image_lock(a.image,local=a.local_image)
    egress_image=guard_reference(a.local_image)
    try: bind=str(ipaddress.IPv4Address(a.bind))
    except ipaddress.AddressValueError as e: raise OpsError('--bind must be an explicit IPv4 address') from e
    state.mkdir(mode=0o700,exist_ok=True); os.chmod(state,0o700)
    for service in SERVICES:
        path=state/service
        if path.is_symlink(): raise OpsError(f'service state path cannot be a symlink: {path}')
        path.mkdir(mode=0o700,exist_ok=True)
        os.chmod(path,0o700)
    secret_dir=state/'secrets'
    if secret_dir.is_symlink(): raise OpsError(f'secrets path cannot be a symlink: {secret_dir}')
    secret_dir.mkdir(mode=0o700,exist_ok=True); os.chmod(secret_dir,0o700)
    write_env(env_path,{'BRIANI_EGRESS_IMAGE':egress_image,'BRIANI_IMAGE':a.image,'BRIANI_LOCAL_IMAGE':str(a.local_image).lower(),'BRIANI_STATE':str(state),'BRIANI_DATA':str(data),'BRIANI_BIND':bind,'BRIANI_UID':str(a.uid),'BRIANI_GID':str(a.gid),'BRIANI_HOSTS':a.hosts})
    print(f'Created protected deployment configuration: {env_path} (0600)')
    print('Start Briani to let the server generate its one-time 30-minute bootstrap code, then display it with show-bootstrap-token.')
    print('Prowlarr API key and qBittorrent first-run password must be obtained from the actual private upstream setup; no credential was generated for those services.')

def command_doctor(a):
    project=project_directory(a.project); env=context(project); data,state=host_validate(Path(env['BRIANI_DATA']),Path(env['BRIANI_STATE']),int(env['BRIANI_UID']),int(env['BRIANI_GID']),a.minimum_free)
    run(['docker','compose','version'],cwd=project)
    run(['docker','info','--format','{{.ServerVersion}}'],cwd=project)
    require_host_capabilities(project)
    compose(project,['config','--quiet'])
    compose(project,['ps','--all'])
    print(f'Linux architecture: {platform.machine()}; state and data mounts writable with {a.minimum_free} free bytes minimum.')
    print('Compose rendering passed. The service table above reports current container state; run qbit-bootstrap and capture-prowlarr-key after first startup.')

def command_up(a):
    project=project_directory(a.project); context(project); require_host_capabilities(project); compose(project,['up','-d'])
    print('Started the pinned Compose stack. qBittorrent and Prowlarr credentials remain private upstream setup steps.')

def command_capture_prowlarr(a):
    project=project_directory(a.project); env=context(project); conf=Path(env['BRIANI_STATE'])/'prowlarr/config.xml'
    if conf.is_symlink() or not conf.is_file(): raise OpsError('Prowlarr config.xml is absent; start the actual Prowlarr container first')
    import xml.etree.ElementTree as ET
    try: root=ET.parse(conf).getroot()
    except ET.ParseError as e: raise OpsError('Prowlarr config.xml is malformed') from e
    node=root.find('ApiKey'); key=(node.text or '').strip() if node is not None else ''
    if not re.fullmatch(r'[A-Fa-f0-9]{32}',key): raise OpsError('Prowlarr config does not contain an actual 32-character API key')
    out=Path(env['BRIANI_STATE'])/'secrets/prowlarr-api-key'
    if out.exists(): raise OpsError(f'{out} already exists; inspect the existing secret before replacing it')
    fd=os.open(out,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f: f.write(key+'\n')
    print(f'Captured Prowlarr API key from actual private config at {conf}; stored mode 0600 at {out}. Key value was not displayed.')

def command_show_bootstrap(a):
    project=project_directory(a.project); env=context(project)
    if not sys.stdout.isatty(): raise OpsError('refusing to print the bootstrap token to a non-interactive output stream')
    path=Path(env['BRIANI_STATE'])/'briani/bootstrap.code'
    if path.is_symlink() or not path.is_file() or (path.stat().st_mode & 0o077): raise OpsError('server bootstrap code is absent or has unsafe permissions; start Briani first')
    print(path.read_text().strip())

def command_qbit_bootstrap(a):
    project=project_directory(a.project); env=context(project)
    require_host_capabilities(project)
    out=Path(env['BRIANI_STATE'])/'secrets/qbittorrent-webui-password'
    if out.exists(): raise OpsError('qBittorrent credential file already exists; inspect before replacing')
    running=compose(project,['ps','--status','running','--services'],capture=True).stdout.splitlines()
    if 'qbittorrent' in running: raise OpsError('qBittorrent is already running; for first setup, run qbit-bootstrap before full-stack up so the current session password remains available')
    # The admin overlay publishes only 127.0.0.1:18080; never use a remote host.
    compose(project,['up','-d','qbittorrent'],admin=True)
    matches=[]
    deadline=time.monotonic()+30
    while time.monotonic()<deadline:
        logs=compose(project,['logs','--no-color','--tail','300','qbittorrent'],admin=True,capture=True).stdout
        matches=re.findall(r'temporary password is provided for this session:\s*([^\s]+)',logs,re.I)
        if matches: break
        time.sleep(1)
    if not matches: raise OpsError('pinned qBittorrent image did not expose its documented temporary password in recent startup logs; no password was guessed')
    temporary=matches[-1]
    if a.interactive:
        new=getpass.getpass('Choose a new qBittorrent Web UI password (12+ characters): ')
        confirm=getpass.getpass('Repeat new qBittorrent Web UI password: ')
    else:
        new=secrets.token_urlsafe(32); confirm=new
    if len(new)<12 or len(new)>128 or new!=confirm: raise OpsError('passwords must match and contain 12 to 128 characters')
    fd=os.open(out,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f: f.write(new+'\n'); f.flush(); os.fsync(f.fileno())
    jar=http.cookiejar.CookieJar(); opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    transport='http://127.0.0.1:18080'
    # qBittorrent validates Origin/Referer against Host. The loopback port is
    # only a transport path; present its internal service origin to the daemon.
    origin='http://qbittorrent:8080'
    def post(path,form):
        req=urllib.request.Request(transport+path,data=urllib.parse.urlencode(form).encode(),headers={'Origin':origin,'Referer':origin+'/','Host':'qbittorrent:8080'})
        try:
            with opener.open(req,timeout=5) as response: return response.read(2048).decode('utf-8','replace').strip()
        except Exception as e: raise OpsError(f'qBittorrent Web UI request failed ({type(e).__name__}); password values were withheld') from e
    def authenticated_version():
        req=urllib.request.Request(transport+'/api/v2/app/version',headers={'Origin':origin,'Referer':origin+'/','Host':'qbittorrent:8080'})
        try:
            with opener.open(req,timeout=5) as response: return response.read(128).decode('utf-8','replace').strip()
        except Exception as e: raise OpsError(f'qBittorrent authenticated API check failed ({type(e).__name__}); password values were withheld') from e
    def login(password):
        post('/api/v2/auth/login',{'username':'admin','password':password})
        # LinuxServer's qBittorrent build scopes the cookie name by WebUI
        # port (for example QBT_SID_8080); do not assume the legacy SID name.
        if not any(cookie.name == 'SID' or cookie.name.startswith('QBT_SID') for cookie in jar): return False
        return bool(authenticated_version())
    try:
        authenticated=login(temporary)
    except OpsError:
        out.unlink(missing_ok=True); raise
    if not authenticated:
        out.unlink(missing_ok=True)
        raise OpsError('qBittorrent rejected the actual logged temporary password')
    import json as jsonmod
    post('/api/v2/app/setPreferences',{'json':jsonmod.dumps({'web_ui_password':new})})
    post('/api/v2/auth/logout',{})
    jar.clear()
    if not login(new): raise OpsError('qBittorrent did not accept the replacement password; protected candidate remains available for recovery')
    post('/api/v2/auth/logout',{})
    print(f'qBittorrent accepted a unique replacement password and it was stored mode 0600 at {out}. The password was not displayed or placed in Compose environment.')

def sha_file(path: Path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
    return h.hexdigest()

def inventory(root: Path):
    rows=[]
    for p in sorted(root.rglob('*')):
        if p.is_symlink(): raise OpsError(f'symlink in service state cannot be backed up safely: {p.relative_to(root)}')
        if p.is_file(): rows.append({'path':p.relative_to(root).as_posix(),'size':p.stat().st_size,'sha256':sha_file(p)})
    return rows

def safe_copy(source:Path,dest:Path):
    dest.mkdir(parents=True,mode=0o700)
    for p in source.rglob('*'):
        rel=p.relative_to(source)
        if p.is_symlink(): raise OpsError(f'symlink in service state: {rel}')
        target=dest/rel
        if p.is_dir(): target.mkdir(parents=True,exist_ok=True,mode=0o700)
        elif p.is_file():
            target.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
            shutil.copy2(p,target)

def verify_backup(backup:Path, *, deployment=False):
    if backup.is_symlink() or not backup.is_dir(): raise OpsError('backup directory is missing or unsafe')
    manifest_path=backup/'manifest.json'
    if manifest_path.is_symlink() or not manifest_path.is_file(): raise OpsError('backup manifest is missing or unsafe')
    manifest=json.loads(manifest_path.read_text())
    if manifest.get('format')!=1: raise OpsError('unsupported backup format')
    if manifest.get('mediaIncluded') is not False: raise OpsError('this CLI accepts configuration-only backups; media restore is separate')
    root=backup/'state'
    if root.is_symlink() or not root.is_dir(): raise OpsError('backup state directory is missing or unsafe')
    expected={}
    for row in manifest['files']:
        rel=Path(row['path'])
        if rel.is_absolute() or '..' in rel.parts: raise OpsError('backup manifest contains unsafe path')
        if rel.as_posix() in expected: raise OpsError('backup manifest contains duplicate paths')
        expected[rel.as_posix()]={'path':rel.as_posix(),'size':int(row['size']),'sha256':row['sha256']}
    actual={row['path']:row for row in inventory(root)}
    if actual!=expected: raise OpsError('backup state content does not match its integrity manifest')
    if deployment:
        envsrc=backup/'deployment.env'
        if envsrc.is_symlink() or not envsrc.is_file() or sha_file(envsrc)!=manifest.get('deploymentEnvSha256'):
            raise OpsError('backup deployment configuration integrity failed')
        metadata=manifest.get('lockMetadataSha256',{})
        if set(metadata)!={'images.lock.json','toolchain.lock.json'}: raise OpsError('backup lacks required image lock metadata')
        for name,digest in metadata.items():
            source=backup/name
            if source.is_symlink() or not source.is_file() or sha_file(source)!=digest: raise OpsError(f'backup lock metadata integrity failed: {name}')
        vals=parse_env(envsrc)
        if manifest.get('images',{}).get('brianiDeploymentReference')!=vals.get('BRIANI_IMAGE'): raise OpsError('backup deployment image does not match its manifest')
    return manifest

def restore_state(backup:Path,dest:Path):
    verify_backup(backup)
    if dest.exists() and any(dest.iterdir()): raise OpsError(f'restore destination must be empty: {dest}')
    if dest.is_symlink(): raise OpsError('restore destination cannot be a symlink')
    root=backup/'state'
    dest.parent.mkdir(parents=True,exist_ok=True)
    staging=dest.parent/f'.{dest.name}.restore-{secrets.token_hex(6)}'
    try:
        safe_copy(root,staging)
        staging.replace(dest)
    except Exception:
        shutil.rmtree(staging,ignore_errors=True)
        raise

def command_backup(a):
    project=project_directory(a.project); env=context(project)
    if a.output.is_symlink(): raise OpsError('backup output cannot be a symlink')
    out=a.output.resolve()
    if out.exists(): raise OpsError(f'backup output must not already exist: {out}')
    require_mounted_parent(out,'backup output')
    state=Path(env['BRIANI_STATE']).resolve()
    if out==state or inside(out,state) or inside(state,out): raise OpsError('backup output and live state must not overlap')
    out.parent.mkdir(parents=True,exist_ok=True)
    running=[]; created=False
    try:
        ps=compose(project,['ps','--status','running','--services'],capture=True)
        running=[name for name in ps.stdout.splitlines() if name in SERVICES]
        compose(project,['stop',*SERVICES]); out.mkdir(mode=0o700); created=True
        safe_copy(state,out/'state')
        (out/'deployment.env').write_text((project/'.env').read_text()); os.chmod(out/'deployment.env',0o600)
        metadata={}
        for name,source in (('images.lock.json',ROOT/'images.lock.json'),('toolchain.lock.json',ROOT/'toolchain.lock.json')):
            if source.is_file():
                shutil.copy2(source,out/name); os.chmod(out/name,0o600); metadata[name]=sha_file(out/name)
        lock=json.loads((out/'images.lock.json').read_text()) if (out/'images.lock.json').exists() else {}
        image_refs={name:record.get('reference') for name,record in lock.get('services',{}).items()}
        image_refs['brianiDeploymentReference']=env['BRIANI_IMAGE']
        manifest={'format':1,'createdUtc':datetime.now(timezone.utc).isoformat(),'mediaIncluded':False,'stateRootNames':['briani','qbittorrent','prowlarr'],'images':image_refs,'deploymentEnvSha256':sha_file(out/'deployment.env'),'lockMetadataSha256':metadata,'files':inventory(out/'state'),'limitations':['media payload is not included','no migration compatibility assertion is implied']}
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n'); os.chmod(out/'manifest.json',0o600)
    except Exception:
        if created: shutil.rmtree(out,ignore_errors=True)
        raise
    finally:
        if running: compose(project,['start',*running])
    print(f'Consistent configuration/state backup created at {out}; media payload excluded.')

def command_restore(a):
    if a.state.is_symlink() or a.project.is_symlink() or a.data and Path(a.data).is_symlink() or a.backup.is_symlink(): raise OpsError('restore paths cannot be symlinks')
    backup=a.backup.resolve(); dest=a.state.resolve(); project=a.project.resolve()
    if project.exists() and any(project.iterdir()): raise OpsError('restore project directory must be empty; use a fresh isolated directory')
    verify_backup(backup,deployment=True)
    vals=parse_env(backup/'deployment.env')
    try: uid,gid=int(vals['BRIANI_UID']),int(vals['BRIANI_GID'])
    except (KeyError,ValueError): raise OpsError('backup deployment ownership is invalid')
    if uid!=os.geteuid() or gid!=os.getegid(): raise OpsError('restore must run as the UID/GID recorded in the backup; no files were copied')
    validate_image_lock(vals['BRIANI_IMAGE'],local=vals.get('BRIANI_LOCAL_IMAGE','false')=='true')
    archived=json.loads((backup/'images.lock.json').read_text())
    current=json.loads((ROOT/'images.lock.json').read_text())
    if any(archived.get('services',{}).get(kind,{}).get('reference') != current.get('services',{}).get(kind,{}).get('reference') for kind in ('qbittorrent','prowlarr')): raise OpsError('backup upstream image pins differ from this release; use the matching audited operations bundle for full-stack rollback')
    original_state=Path(vals['BRIANI_STATE']).resolve(); vals['BRIANI_STATE']=str(dest)
    data=Path(a.data).resolve()
    require_mounted_parent(data,'restore data')
    require_mounted_parent(dest,'restore state')
    if dest==data or inside(dest,data) or inside(data,dest): raise OpsError('restore state and data destinations must not overlap')
    if dest.exists() and any(dest.iterdir()): raise OpsError('restore state destination must be empty')
    if inside(dest,original_state) or inside(original_state,dest): raise OpsError('restore state must be disjoint from the original live state')
    protected=(backup,dest,data,original_state)
    if any(inside(project,root) or inside(root,project) for root in protected): raise OpsError('restore project must be disjoint from backup, state and media roots')
    if inside(dest,backup) or inside(backup,dest): raise OpsError('restore state and backup must not overlap')
    if inside(data,dest) or inside(dest,data): raise OpsError('restore state and data must not overlap')
    if inside(data,backup) or inside(backup,data): raise OpsError('restore data and backup must not overlap')
    if inside(data,original_state) or inside(original_state,data): raise OpsError('restore data must not overlap original state')
    if data.exists() and any(data.iterdir()) and not a.allow_existing_data: raise OpsError('data path must be empty for isolated restore (or pass --allow-existing-data explicitly)')
    valid_path(data,'restore data',create=True)
    restore_state(backup,dest)
    project.mkdir(parents=True,exist_ok=True,mode=0o700)
    vals['BRIANI_DATA']=str(data); write_env(project/'.env',vals)
    print(f'Restored service configuration to isolated state {dest} and project {project}. Media payload was not restored.')

def command_upgrade(a):
    project=project_directory(a.project); env=context(project); backup=a.backup.resolve()
    manifest=verify_backup(backup,deployment=True)
    if not manifest.get('files'): raise OpsError('a verified matching configuration backup is required before upgrade')
    saved=parse_env(backup/'deployment.env')
    if any(saved.get(key)!=env.get(key) for key in ('BRIANI_STATE','BRIANI_DATA','BRIANI_UID','BRIANI_GID','BRIANI_BIND')): raise OpsError('backup does not match this deployment identity and storage roots')
    if manifest['images'].get('brianiDeploymentReference')!=env['BRIANI_IMAGE']: raise OpsError('backup image reference does not match current deployment; upgrade needs an explicit compatibility baseline')
    if not a.compatibility_file or not a.compatibility_file.is_file(): raise OpsError('provide a reviewed compatibility file before upgrade; automatic DB backward-compatibility cannot be inferred')
    compat=json.loads(a.compatibility_file.read_text())
    if compat.get('fromImage')!=env['BRIANI_IMAGE'] or compat.get('toImage')!=a.image or compat.get('compatible') is not True: raise OpsError('compatibility file does not approve this exact image transition')
    if not re.fullmatch(r'.+@sha256:[0-9a-f]{64}',a.image): raise OpsError('target image must be pinned by sha256 digest')
    validate_image_lock(a.image,allow_history=False)
    vals=dict(env); vals['BRIANI_IMAGE']=a.image; write_env(project/'.env',vals)
    try:
        compose(project,['pull']); compose(project,['up','-d','--remove-orphans'])
        ps=compose(project,['ps','--status','running','--services'],capture=True)
        running=set(ps.stdout.splitlines())
        if not set(SERVICES).issubset(running): raise OpsError('upgrade started, but not every service is running; inspect `doctor` and preserve the matching backup; do not start an older image against this state')
    except Exception:
        # Keep the selected target in .env. The DB may have migrated; never point
        # the old image back at it automatically. Recovery uses isolated restore.
        raise
    print('Upgrade completed. Keep the verified pre-upgrade backup for rollback.')

def command_rollback(a):
    # Rollback must restore state into a fresh deployment project before starting old images.
    args=argparse.Namespace(backup=a.backup,state=a.state,data=a.data,project=a.project,allow_existing_data=a.allow_existing_data)
    command_restore(args)

def parser():
    p=argparse.ArgumentParser(description=__doc__); sub=p.add_subparsers(dest='cmd',required=True)
    q=sub.add_parser('init'); q.add_argument('--project',type=Path,default=Path.cwd()); q.add_argument('--data',required=True); q.add_argument('--state',required=True); q.add_argument('--bind',required=True); q.add_argument('--uid',type=int,required=True); q.add_argument('--gid',type=int,required=True); q.add_argument('--image',required=True); q.add_argument('--local-image',action='store_true'); q.add_argument('--hosts',default='localhost;127.0.0.1;briani'); q.add_argument('--minimum-free',type=int,default=5*1024**3); q.add_argument('--replace',action='store_true'); q.set_defaults(fn=command_init)
    q=sub.add_parser('doctor'); q.add_argument('--project',type=Path,default=Path.cwd()); q.add_argument('--minimum-free',type=int,default=5*1024**3); q.set_defaults(fn=command_doctor)
    q=sub.add_parser('up'); q.add_argument('--project',type=Path,default=Path.cwd()); q.set_defaults(fn=command_up)
    q=sub.add_parser('capture-prowlarr-key'); q.add_argument('--project',type=Path,default=Path.cwd()); q.set_defaults(fn=command_capture_prowlarr)
    q=sub.add_parser('show-bootstrap-token'); q.add_argument('--project',type=Path,default=Path.cwd()); q.set_defaults(fn=command_show_bootstrap)
    q=sub.add_parser('qbit-bootstrap'); q.add_argument('--project',type=Path,default=Path.cwd()); q.add_argument('--interactive',action='store_true',help='choose and confirm the replacement password in this terminal instead of generating one'); q.set_defaults(fn=command_qbit_bootstrap)
    q=sub.add_parser('backup'); q.add_argument('--project',type=Path,default=Path.cwd()); q.add_argument('--output',type=Path,required=True); q.set_defaults(fn=command_backup)
    q=sub.add_parser('restore'); q.add_argument('--backup',type=Path,required=True); q.add_argument('--project',type=Path,required=True); q.add_argument('--state',type=Path,required=True); q.add_argument('--data',required=True); q.add_argument('--allow-existing-data',action='store_true'); q.set_defaults(fn=command_restore)
    q=sub.add_parser('upgrade'); q.add_argument('--project',type=Path,default=Path.cwd()); q.add_argument('--backup',type=Path,required=True); q.add_argument('--image',required=True); q.add_argument('--compatibility-file',type=Path); q.set_defaults(fn=command_upgrade)
    q=sub.add_parser('rollback'); q.add_argument('--backup',type=Path,required=True); q.add_argument('--project',type=Path,required=True); q.add_argument('--state',type=Path,required=True); q.add_argument('--data',required=True); q.add_argument('--allow-existing-data',action='store_true'); q.set_defaults(fn=command_rollback)
    return p

def main(argv=None):
    try:
        signal.signal(signal.SIGTERM, lambda _signum,_frame: (_ for _ in ()).throw(KeyboardInterrupt()))
        a=parser().parse_args(argv); a.fn(a); return 0
    except KeyboardInterrupt:
        print('operations: interrupted; maintenance cleanup ran where applicable',file=sys.stderr); return 130
    except (OpsError,OSError,ValueError,KeyError,json.JSONDecodeError) as e:
        print(f'operations: {e}',file=sys.stderr); return 2
if __name__=='__main__': raise SystemExit(main())
