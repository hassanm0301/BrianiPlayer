#!/usr/bin/env python3
"""Exercise the actual isolated Docker application with generated offline media."""
import json,secrets,shutil,subprocess,time,urllib.request,urllib.parse,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    run=ROOT/'artifacts/media-container'/uuid.uuid4().hex
    data=run/'data'/'library';state=run/'state';data.mkdir(parents=True);state.mkdir()
    for source,target in [('synthetic.mp4','generated.mp4'),('photo.jpg','generated.jpg')]:
        fixture=Path('/tmp/briani-media-fixtures')/source
        if fixture.exists():shutil.copyfile(fixture,data/target)
        else:
            args=['ffmpeg','-v','error','-y','-filter_threads','1','-f','lavfi','-i','testsrc2=size=320x180:rate=10','-threads','1']
            args+=['-t','3','-c:v','libx264','-movflags','+faststart'] if target.endswith('.mp4') else ['-frames:v','1','-c:v','mjpeg']
            subprocess.run([*args,str(data/target)],check=True,capture_output=True,timeout=20)
    name='briani-media-test-'+uuid.uuid4().hex[:12]
    def docker(*args):return subprocess.run(['docker',*args],check=True,capture_output=True,text=True).stdout.strip()
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}));token=None
    def request(path,body=None,headers=None):
        encoded=None if body is None else json.dumps(body).encode()
        h={'Content-Type':'application/json',**(headers or {})}
        if token:h['Authorization']='Bearer '+token
        with opener.open(urllib.request.Request(origin+path,data=encoded,headers=h),timeout=10) as response:return response.status,dict(response.headers),response.read()
    def json_request(path,body=None):return json.loads(request(path,body)[2])
    try:
        docker('run','--detach','--name',name,'--read-only','--cap-drop=ALL','--security-opt=no-new-privileges','--pids-limit=256','--memory=1g','--cpus=2','--tmpfs','/tmp:rw,noexec,nosuid,size=64m','-p','127.0.0.1::8088','-v',str(data.parent)+':/data','-v',str(state)+':/config','briani-server:dev')
        port=json.loads(docker('inspect','--format','{{json .NetworkSettings.Ports}}',name))['8088/tcp'][0]['HostPort'];origin='http://127.0.0.1:'+port
        deadline=time.monotonic()+30
        while True:
            try:assert json_request('/readyz')['status']=='ready';break
            except OSError:
                if time.monotonic()>deadline:raise RuntimeError('Container readiness timed out')
                time.sleep(.2)
        code=(state/'bootstrap.code').read_text()
        password=secrets.token_urlsafe(32)
        auth=json_request('/api/v1/bootstrap',{'code':code,'username':'fixture-admin','displayName':'Fixture','password':password,'confirmPassword':password})
        token=auth['accessToken'];storage=json_request('/api/v1/admin/storage')
        roots=storage if isinstance(storage,list) else storage['items'];rootid=roots[0]['id']
        library=json_request('/api/v1/libraries',{'name':'Offline generated media','storageRootId':rootid,'relativePath':'library','readOnly':False})
        libraryid=library['id'];job=json_request('/api/v1/libraries/'+libraryid+'/scan',{})
        deadline=time.monotonic()+120
        while True:
            entries=json_request('/api/v1/libraries/'+libraryid+'/entries')['items']
            media=[json_request('/api/v1/media/'+item['id']) for item in entries if item['kind']!='folder']
            if len(media)==2 and all(item['probeState']=='ready' for item in media):break
            if time.monotonic()>deadline:
                states=[{'kind':item['kind'],'probeState':item['probeState']} for item in media]
                raise RuntimeError('Bounded native scan/probe failed: '+json.dumps(states))
            time.sleep(.3)
        results=[]
        for item in media:
            status,headers,thumb=request('/api/v1/media/'+item['id']+'/thumbnail');assert status==200 and thumb[:2]==b'\xff\xd8' and len(thumb)<=524288
            if item['kind']=='photo':
                status,headers,content=request('/api/v1/media/'+item['id']+'/image');assert content==(data/'generated.jpg').read_bytes()
            else:
                playback=json_request('/api/v1/playback/sessions',{'target':{'kind':'media','id':item['id']},'mode':'internal'})
                path=urllib.parse.urlparse(playback['streamUrl']).path
                status,headers,content=request(path,headers={'Range':'bytes=7-1031'});assert status==206 and content==(data/'generated.mp4').read_bytes()[7:1032]
            results.append({'kind':item['kind'],'probeState':item['probeState'],'thumbnailBytes':len(thumb),'exactDelivery':True})
        report={'passed':True,'architecture':'linux/amd64','upstreamConfigured':False,'media':results,'containerImage':docker('inspect','--format','{{.Image}}',name)}
        (run/'result.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS offline Docker scan, native metadata, JPEG thumbnails, photo bytes and completed video Range');print('Evidence:',run.relative_to(ROOT))
    finally:
        try:docker('rm','--force',name)
        except subprocess.CalledProcessError:pass

if __name__=='__main__':main()
