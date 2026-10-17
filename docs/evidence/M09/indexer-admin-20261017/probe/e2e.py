import json,sys,urllib.request,urllib.error,secrets,os
B='http://127.0.0.1:28088'; E=sys.argv[1]; KEY=open(sys.argv[2]).read().strip()
def call(method,path,body=None,token=None):
    data=None if body is None else json.dumps(body).encode()
    req=urllib.request.Request(B+path,data=data,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
    try:
        with urllib.request.urlopen(req,timeout=30) as r: raw=r.read(); return r.status,(json.loads(raw) if raw else None),raw
    except urllib.error.HTTPError as e:
        raw=e.read(); return e.code,(json.loads(raw) if raw else None),raw
code=open(os.path.join(E,'state','bootstrap.code')).read().strip()
pw=secrets.token_urlsafe(16)
s,a,_=call('POST','/api/v1/bootstrap',{'code':code,'username':'e2eadmin','displayName':'E2E Admin','password':pw,'confirmPassword':pw}); print('bootstrap',s)
tok=a['accessToken']
s,b,_=call('PUT','/api/v1/admin/integrations/prowlarr',{'baseUrl':'http://127.0.0.1:29696/','version':1,'secret':KEY},tok); print('integration',s)
log=[]

def show(name,s,b,raw):
    txt=raw.decode() if raw else ''
    leak=any(x in txt for x in ['fixture-secret-123',KEY])
    print(f'{name}: {s} leak={leak}'); log.append({'step':name,'status':s,'leak':leak,'body':b})
    return b
show('list (before)',*call('GET','/api/v1/admin/indexers',token=tok))
s,defs,raw=call('GET','/api/v1/admin/indexers/definitions',token=tok); print('definitions',s,len(defs),'addable',sum(1 for d in defs if d['addable']),'bytes',len(raw))
fx=[d for d in defs if d['key']=='brianifixture'][0]; print(fx)
print([ (d['key'],d['setupNote']) for d in defs if not d['addable']][:6])
import collections
notes=collections.Counter(d['setupNote'] for d in defs if not d['addable'])
print('setup notes',dict(notes))
print('recommended', {k:[d['addable'] for d in defs if d['key']==k] for k in ('linuxtracker','pandacd')})
log.append({'step':'definitions','total':len(defs),'addable':sum(1 for d in defs if d['addable']),'notes':dict(notes),'linuxtracker':[d['addable'] for d in defs if d['key']=='linuxtracker'],'pandacd':[d['addable'] for d in defs if d['key']=='pandacd'],'bytes':len(raw),'leak':any(x in raw.decode() for x in ['fixture-secret-123',KEY])})
s,detail,raw=call('GET','/api/v1/admin/indexers/definitions/brianifixture',token=tok); print('detail',s); print(json.dumps(detail,indent=1))
show('create wrong key',*call('POST','/api/v1/admin/indexers',{'definition':'brianifixture','name':'E2E fixture','settings':{'apikey':'wrong-key-value','sort':'1','freeleech':'false'}},tok))
s,created,raw=call('POST','/api/v1/admin/indexers',{'definition':'brianifixture','name':'E2E fixture','settings':{'apikey':'fixture-secret-123','sort':'1'}},tok); show('create good',s,created,raw)
iid=created['id']
show('list',*call('GET','/api/v1/admin/indexers',token=tok))
show('test',*call('POST',f'/api/v1/admin/indexers/{iid}/test',token=tok))
show('disable',*call('PATCH',f'/api/v1/admin/indexers/{iid}',{'enabled':False},tok))
show('disable again (no-op)',*call('PATCH',f'/api/v1/admin/indexers/{iid}',{'enabled':False},tok))
show('enable',*call('PATCH',f'/api/v1/admin/indexers/{iid}',{'enabled':True},tok))
show('test after toggle',*call('POST',f'/api/v1/admin/indexers/{iid}/test',token=tok))
show('discovery providers',*call('GET','/api/v1/discovery/providers',token=tok))
show('bad field',*call('POST','/api/v1/admin/indexers',{'definition':'brianifixture','settings':{'bogus':'x'}},tok))
show('bad select',*call('POST','/api/v1/admin/indexers',{'definition':'brianifixture','settings':{'sort':'7'}},tok))
show('setup in prowlarr',*call('POST','/api/v1/admin/indexers',{'definition':'Torznab-1'},tok))
show('traversal',*call('GET','/api/v1/admin/indexers/..%2F..%2Fsystem%2Fstatus/test',token=tok))
mpw=secrets.token_urlsafe(16)
s,u,_=call('POST','/api/v1/admin/users',{'username':'e2emember','displayName':'Member','password':mpw,'confirmPassword':mpw,'role':'member'},tok); print('member',s)
s,m,_=call('POST','/api/v1/auth/login',{'username':'e2emember','password':mpw,'deviceName':'e2e'}); print('member login',s)
mt=m['accessToken'] if m and 'accessToken' in m else None
for meth,path,body in [('GET','/api/v1/admin/indexers',None),('GET','/api/v1/admin/indexers/definitions',None),('POST','/api/v1/admin/indexers',{'definition':'brianifixture'}),('PATCH',f'/api/v1/admin/indexers/{iid}',{'enabled':False}),('POST',f'/api/v1/admin/indexers/{iid}/test',None),('DELETE',f'/api/v1/admin/indexers/{iid}',None)]:
    s,_,_=call(meth,path,body,mt); print('member',meth,path,s)
show('delete',*call('DELETE',f'/api/v1/admin/indexers/{iid}',token=tok))
show('delete again',*call('DELETE',f'/api/v1/admin/indexers/{iid}',token=tok))
show('list (after)',*call('GET','/api/v1/admin/indexers',token=tok))
s,audit,_=call('GET','/api/v1/admin/audit?limit=10',token=tok); print('audit',[x['action'] for x in audit['items']])
json.dump(log,open(os.path.join(E,'e2e-log.json'),'w'),indent=1)
