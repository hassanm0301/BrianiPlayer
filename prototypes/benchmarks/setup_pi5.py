#!/usr/bin/env python3
"""Prepare an explicitly owned native Pi fixture stack; never discover production resources."""
import argparse, hashlib, importlib.util, json, os, pathlib, secrets, shutil, socket, sqlite3, subprocess, time, urllib.request, uuid
ROOT=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('pi_fixture_helpers',ROOT/'prototypes/client/run_desktop_e2e.py')
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
PROWLARR='lscr.io/linuxserver/prowlarr@sha256:f9151e5bc1025c6d0a630d503210cdcb6bb55a7cc098562609d96a408d838902'

class CanonicalQbitHeaders(urllib.request.BaseHandler):
 def http_request(self, request):
  for name,value in {'Host':'qbittorrent:8080','Origin':'http://qbittorrent:8080','Referer':'http://qbittorrent:8080/'}.items():
   request.remove_header(name);request.add_unredirected_header(name,value)
  return request

class PortQbit(h.Qbit):
 def __init__(self, origin, password):
  self.origin,self.password=origin,password
  self.cookie=''
  self.opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),CanonicalQbitHeaders())
  self.login()

def digest_file(path):
 d=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''):d.update(block)
 return d.hexdigest()

def setup(args):
 if args.root.is_symlink():raise RuntimeError('fixture-root symlink rejected')
 root=args.root.resolve(); marker=root/'owner.marker'
 if marker.is_symlink() or marker.read_text().strip()!=args.owner or root.parent!=pathlib.Path('/mnt/hassan-hdd1'):
  raise RuntimeError('explicit fixture-root ownership mismatch')
 for tree in (root/'runtime',root/'fixtures'):
  if tree.is_symlink():raise RuntimeError('fixture descendant symlink rejected')
  for current,dirs,files in os.walk(tree,followlinks=False):
   if any((pathlib.Path(current)/name).is_symlink() for name in dirs+files):raise RuntimeError('fixture descendant symlink rejected')
 available=next(int(line.split()[1])*1024 for line in pathlib.Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemAvailable:'))
 if available<1536*1024**2:raise RuntimeError('insufficient host MemAvailable for an isolated fixture startup')
 if h.docker('info','--format','{{json .MemoryLimit}}')!='true':
  print('VERIFICATION LIMITATION: native Docker cannot enforce memory caps; host memory will be guarded during the workload.',flush=True)
 runtime=root/'runtime'
 if runtime.exists() and not args.resume:raise RuntimeError('runtime destination must be new and empty; use explicit owned resume only')
 project='briani-pi-'+args.owner.rsplit('-',1)[-1]
 existing=h.docker('ps','-aq','--filter','label=com.docker.compose.project='+project)
 if existing and not args.resume:raise RuntimeError('fixture project already exists')
 if existing:
  for identity in existing.splitlines():
   record=json.loads(h.docker('inspect',identity))[0]
   if record['Config'].get('Labels',{}).get('org.brianiplayer.owner')!=args.owner:raise RuntimeError('resume container ownership mismatch')
   for mount in record.get('Mounts',[]):
    if mount.get('Type')=='bind' and not pathlib.Path(mount['Source']).resolve().is_relative_to(root):raise RuntimeError('resume bind mount escapes fixture root')
 for port in (() if args.resume else (28088,28080,28081)):
  with socket.socket() as s:s.bind(('127.0.0.1',port))
 runtime.mkdir(mode=0o700,exist_ok=True)
 for p in ['data','state','state/briani','state/qbittorrent','state/prowlarr','state/seeder','state/secrets']:(runtime/p).mkdir(mode=0o700,exist_ok=True)
 library_path=runtime/'data/library';library_path.mkdir(mode=0o700,exist_ok=True);(library_path/'catalog').mkdir(exist_ok=True)
 # The root catalog folder and two videos also count toward the scanner's
 # 10000-entry safety bound. This fixture indexes exactly that many entries.
 for i in range(9997):(library_path/'catalog'/f'entry-{i:05d}').mkdir(exist_ok=True)
 for i in range(9997,10000):
  excess=library_path/'catalog'/f'entry-{i:05d}'
  if excess.exists():excess.rmdir()
 for name in ['completed-a.mkv','completed-b.mkv']:shutil.copyfile(root/'fixtures/completed-a.mkv',library_path/name)
 source=root/'fixtures/progressive.mkv'
 if source.is_symlink() or not source.is_file() or not 2*1024**3<source.stat().st_size<8*1024**3:raise RuntimeError('generated progressive fixture size/path mismatch')
 info={b'length':source.stat().st_size,b'name':b'progressive.mkv',b'piece length':262144,b'private':1}
 torrent=runtime/'fixture.torrent'
 cached=h.bdecode(torrent.read_bytes()).get(b'info') if args.resume and torrent.exists() else None
 if isinstance(cached,dict) and all(cached.get(key)==value for key,value in info.items()) and len(cached.get(b'pieces',b''))==20*((source.stat().st_size+262143)//262144):
  info=cached
  print('Reusing metainfo from this owned fixture; workload still prehashes its independent source oracle.',flush=True)
 else:
  pieces=bytearray()
  with source.open('rb') as f:
   for block in iter(lambda:f.read(262144),b''):pieces.extend(hashlib.sha1(block).digest())
  info[b'pieces']=bytes(pieces);torrent.write_bytes(h.bencode({b'info':info}))
 torrent_hash=hashlib.sha1(h.bencode(info)).hexdigest()
 print('Generated fixture metainfo; starting owned Compose services.',flush=True)
 labels={'org.brianiplayer.fixture':'true','org.brianiplayer.owner':args.owner}
 common={'labels':labels,'restart':'no','cpu_shares':128,'pids_limit':256}
 api={**common,'image':args.server_image,'user':f'{os.getuid()}:{os.getgid()}','mem_limit':'1g','cpus':2,'read_only':True,'cap_drop':['ALL'],'security_opt':['no-new-privileges:true'],'tmpfs':['/tmp:rw,noexec,nosuid,size=64m'],
      'environment':{'ASPNETCORE_HTTP_PORTS':'8088','AllowedHosts':'localhost;127.0.0.1;briani'},'ports':['127.0.0.1:28088:8088'],'volumes':[f'{runtime}/state/briani:/config',f'{runtime}/data:/data',f'{runtime}/state/secrets:/run/briani-secrets:ro'],'networks':['control','access']}
 def qbit(role,port):
  value={**common,'image':h.QBIT_IMAGE,'cpus':.75,'mem_limit':'256m','environment':{'PUID':str(os.getuid()),'PGID':str(os.getgid()),'WEBUI_PORT':'8080','TORRENTING_PORT':'6881'},'volumes':[f'{runtime}/state/{role}:/config']}
  if role=='qbittorrent':value.update(network_mode='service:torrent-egress-guard',depends_on={'torrent-egress-guard':{'condition':'service_healthy'}},volumes=value['volumes']+[f'{runtime}/data:/data'])
  else:value.update(networks=['control','access'],ports=[f'127.0.0.1:{port}:8080'],volumes=value['volumes']+[f'{root}/fixtures:/data'])
  return value
 services={'briani':api,'qbittorrent':qbit('qbittorrent',28080),'fixture-seeder':qbit('seeder',28081),
  'torrent-egress-guard':{**common,'image':args.guard_image,'cpus':.1,'mem_limit':'32m','pids_limit':16,'read_only':True,'cap_drop':['ALL'],'cap_add':['NET_ADMIN'],'security_opt':['no-new-privileges:true'],'networks':{'control':{'aliases':['qbittorrent']},'access':{}},'ports':['127.0.0.1:28080:8080']},
  'prowlarr':{**common,'image':PROWLARR,'cpus':.5,'mem_limit':'256m','environment':{'PUID':str(os.getuid()),'PGID':str(os.getgid())},'volumes':[f'{runtime}/state/prowlarr:/config'],'networks':['control','access']}}
 compose=runtime/'compose.json';compose.write_text(json.dumps({'services':services,'networks':{'control':{'internal':True},'access':{}}},indent=2));compose.chmod(0o600)
 command=['docker','compose','--project-name',project,'--file',str(compose)]
 subprocess.run([*command,'up','-d'],check=True,stdout=subprocess.DEVNULL)
 def cid(role):return h.docker('compose','--project-name',project,'--file',str(compose),'ps','-q',role)
 def private_password(role):
  found=h.TEMP_PASSWORD.search(h.docker('logs',cid(role)));return found.group(1) if found else None
 def upstream(role,port):
  credential=runtime/'state/secrets'/('qbittorrent-webui-password' if role=='qbittorrent' else 'fixture-seeder-password')
  password=credential.read_text() if credential.exists() else h.wait_for(role+' private startup',lambda:private_password(role),120)
  h.wait_for(role+' listener',lambda: _ready(port),60)
  client=PortQbit('http://127.0.0.1:'+str(port),password)
  if credential.exists():return client
  replacement=secrets.token_urlsafe(32)
  client.call('app/setPreferences',{'json':json.dumps({'web_ui_password':replacement,'dht':False,'pex':False,'lsd':False,'upnp':False,'web_ui_upnp':False,'max_connec':80,'max_connec_per_torrent':40})})
  _private(credential,replacement)
  return PortQbit('http://127.0.0.1:'+str(port),replacement)
 downloader=upstream('qbittorrent',28080);seeder=upstream('fixture-seeder',28081)
 print('Owned qBittorrent credentials verified.',flush=True)
 # The only private destination exception is this explicitly owned seeder's
 # exact IPv4/6881, in this fixture guard namespace, never the host firewall.
 seed_record=json.loads(h.docker('inspect',cid('fixture-seeder')))[0]
 seed_ip=next(iter(seed_record['NetworkSettings']['Networks'].values()))['IPAddress']
 h.docker('exec',cid('torrent-egress-guard'),'nft','insert','rule','inet','briani_egress','output','ip','daddr',seed_ip,'meta','l4proto','{','tcp',',','udp','}','th','dport','6881','counter','accept')
 if not any(x['hash']==torrent_hash for x in seeder.json('torrents/info')):seeder.add_torrent(torrent,'/data')
 seeder.call('torrents/start',{'hashes':torrent_hash})
 h.wait_for('owned complete seed',lambda: next((t for t in seeder.json('torrents/info') if t['hash']==torrent_hash and t['progress']==1),None),600)
 print('Generated seed verified; preparing API catalog.',flush=True)
 api=h.Api('http://127.0.0.1:28088')
 original_request=api.request
 def request(path,*a,**kw):kw['headers']={'Host':'127.0.0.1:28088',**kw.get('headers',{})};return original_request(path,*a,**kw)
 api.request=request
 h.wait_for('native Briani readiness',lambda: _api_ready(api),120)
 admin_credential=runtime/'state/secrets/fixture-admin-password'
 if not admin_credential.exists():_private(admin_credential,secrets.token_urlsafe(32))
 password=admin_credential.read_text()
 if api.json('/api/v1/server')['bootstrapRequired']:
  auth=api.json('/api/v1/bootstrap',{'code':(runtime/'state/briani/bootstrap.code').read_text().strip(),'username':'pibenchadmin','displayName':'Owned Pi fixture','password':password,'confirmPassword':password})
 else:auth=api.json('/api/v1/auth/login',{'username':'pibenchadmin','password':password,'deviceName':'Owned Pi setup resume'})
 api.token=auth['accessToken']
 root_id=api.json('/api/v1/admin/storage')[0]['id']
 library=next((x for x in api.json('/api/v1/libraries') if x['name']=='Owned Pi workload'),None)
 if library is None:library=api.json('/api/v1/libraries',{'name':'Owned Pi workload','description':'Isolated generated fixtures','storageRootId':root_id,'relativePath':'library','readOnly':False})
 library_id=library['id']
 api.json('/api/v1/admin/maintenance',{'action':'rescanLibraries','libraryId':library_id})
 entries=h.wait_for('catalog and completed files',lambda:_catalog(api,library_id),180)
 def indexed_catalog():
  try:
   with sqlite3.connect('file:'+str(runtime/'state/briani/briani.db')+'?mode=ro',uri=True) as db:
    count=db.execute("SELECT COUNT(*) FROM media_items WHERE ParentRelativePath='catalog' AND Kind='folder' AND Lifecycle='available'").fetchone()[0]
    return count if count==9997 else None
  except sqlite3.Error:return None
 h.wait_for('10000 indexed library entries',indexed_catalog,600)
 catalog=next(x for x in entries if x.get('name')=='catalog')
 videos=[next(x for x in entries if x.get('name')==name) for name in ['completed-a.mkv','completed-b.mkv']]
 users=[]
 for i in range(5):
  username=f'pibenchuser{i}';user_password=secrets.token_urlsafe(32)
  user=api.json('/api/v1/admin/users',{'username':username,'displayName':username,'password':user_password,'confirmPassword':user_password,'role':'member'})
  granted=api.json('/api/v1/libraries/'+library_id+'/grants')
  api.json('/api/v1/libraries/'+library_id+'/grants',{'version':granted['version'],'grants':[{key:value for key,value in g.items() if key in {'userId','read','download','manage','quotaBytes'}} for g in granted['grants']]+[{'userId':user['id'],'read':True,'download':False,'manage':False,'quotaBytes':None}]},method='PUT')
  token=api.json('/api/v1/auth/login',{'username':username,'password':user_password,'deviceName':f'Pi folder workload {i}'})
  users.append({'name':username,'bearer':token['accessToken'],'refreshToken':token['refreshToken'],'url':f'/api/v1/libraries/{library_id}/entries?folderId={catalog["id"]}&limit=200'})
 upload=h.multipart_torrent(api,torrent);download=api.json('/api/v1/downloads',{'libraryId':library_id,'source':{'kind':'torrentUpload','value':upload['id']}})
 request_id=download['id'];files=h.wait_for('progressive torrent metadata',lambda:h.api_files(api,request_id),120);file=next(x for x in files if x['kind']=='video')
 current=api.json('/api/v1/downloads/'+request_id)
 api.json('/api/v1/downloads/'+request_id+'/selection',{'files':[{'fileId':file['id'],'selected':True,'priority':'normal'}],'autoStart':True,'version':current['version']},method='PUT')
 h.wait_for('owned downloader registration',lambda:next((x for x in downloader.json('torrents/info') if x['hash']==torrent_hash),None),60)
 downloader.call('torrents/setDownloadLimit',{'hashes':torrent_hash,'limit':str(3300*1024)})
 downloader.call('torrents/addPeers',{'hashes':torrent_hash,'peers':seed_ip+':6881'})
 h.wait_for('verified early prefix',lambda:h._ready_file(api,request_id,file['id']),180)
 h.download_action(api,request_id,'pause')
 h.wait_for('owned downloader paused',lambda:next((x for x in downloader.json('torrents/info') if x['hash']==torrent_hash and x['state'].startswith(('stopped','paused'))),None),30)
 before=next(x for x in downloader.json('torrents/info') if x['hash']==torrent_hash)
 if before['progress']>=1:raise RuntimeError('progressive fixture completed before workload')
 streams=[]
 for i,target in enumerate([{'kind':'media','id':v['id']} for v in videos]+[{'kind':'downloadFile','id':file['id']}]):
  own=api.json('/api/v1/auth/login',{'username':'pibenchadmin','password':password,'deviceName':f'Pi stream owner {i}'})
  previous=api.token;api.token=own['accessToken'];session=api.json('/api/v1/playback/sessions',{'target':target,'mode':'internal'});api.token=previous
  oracle=library_path/['completed-a.mkv','completed-b.mkv'][i] if i<2 else source
  streams.append({'url':session['streamUrl'],'bearer':own['accessToken'],'refreshToken':own['refreshToken'],'playbackSessionId':session['id'],'generation':session['generation'],'bytes':oracle.stat().st_size,'sha256':digest_file(oracle),'oracleFile':str(oracle),'targetMbitPerSecond':25 if i<2 else 15})
 streams[2].update(downloadStatusUrl='/api/v1/downloads/'+request_id,downloadRatePointer='/downloadBps',minimumDownloadBytesPerSecond=3125000)
 _private(runtime/'workload.json',json.dumps({'baseUrl':'http://127.0.0.1:28088','folderUsers':users,'completedStreams':streams[:2],'progressiveStream':streams[2]}))
 ids=[cid(role) for role in ['briani','qbittorrent','prowlarr','torrent-egress-guard']]
 (runtime/'setup-evidence.json').write_text(json.dumps({'status':'prepared','project':project,'containerIds':ids,'seedContainerId':cid('fixture-seeder'),'torrentHash':torrent_hash,'downloadPaused':True,'progressBeforeWorkload':before['progress'],'fixtureBytes':source.stat().st_size,'fixtureSha256':streams[2]['sha256'],'catalogFolders':9997,'libraryEntries':10000,'cooling':'small CPU heatsink; no fan reported','memoryLimits':'must check native Docker capability'},indent=2)+'\n')
 print('Prepared owned native fixture stack and private workload configuration; no benchmark pass claimed.')

def _private(path,value):
 fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
 with os.fdopen(fd,'w') as f:f.write(value)
def _ready(port):
 try:
  with socket.create_connection(('127.0.0.1',port),timeout=1):return True
 except OSError:return False
def _api_ready(api):
 try:return api.json('/readyz').get('status')=='ready'
 except (OSError,RuntimeError):return False
def _catalog(api,library):
 items=api.json('/api/v1/libraries/'+library+'/entries?limit=200')['items']
 return items if all(any(x.get('name')==n for x in items) for n in ['catalog','completed-a.mkv','completed-b.mkv']) else None
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,required=True);p.add_argument('--owner',required=True);p.add_argument('--server-image',required=True);p.add_argument('--guard-image',required=True);p.add_argument('--resume',action='store_true');args=p.parse_args();setup(args)
