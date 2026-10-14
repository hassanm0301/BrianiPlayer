#!/usr/bin/env python3
"""Independent actual-daemon egress cases; only own labeled namespaces change."""
from __future__ import annotations
import argparse, hashlib, importlib.util, ipaddress, json, os, pathlib, subprocess, tempfile, time, uuid
ROOT=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('briani_egress_helpers',ROOT/'prototypes/client/run_desktop_e2e.py')
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
DOCKER=['docker','--config',str(ROOT/'.tools/docker-config')]
FIXTURE=ROOT/'tests/security/probe_fixture.py'

def docker(*args):
    r=subprocess.run([*DOCKER,*map(str,args)],capture_output=True,text=True,timeout=90)
    if r.returncode:raise RuntimeError(f'owned Docker {args[0]} failed ({r.returncode})')
    return r.stdout.strip()

def decide(positive_hits,blocked_packets,target_hits,*,phases_ok=True):
    if target_hits:return 'failed'
    return 'passed' if positive_hits and blocked_packets and phases_ok else 'not_proven'

def fixture_rule(address,port,comment,*,allow=False):
    if not ipaddress.IPv4Address(address).is_private or not 1<=port<=65535:raise ValueError('exact private fixture target required')
    # Negative rules only COUNT, then continue to the production policy. A
    # test-created reject would conceal a missing production deny rule.
    return ['ip','daddr',address,'tcp','dport',str(port),'counter',*(['accept'] if allow else []),'comment',comment]

def probe(output,guard_image='briani-egress:m10',fixture_image='briani-vlc-proof:dev'):
    if output.resolve()==(ROOT/'docs/evidence/M10/egress.json').resolve():raise ValueError('preserve baseline egress.json; use extended output')
    run=uuid.uuid4().hex;network='briani-egress-'+run[:12]
    names={role:network+'-'+role for role in ('origin','sink','guard','engine')};owned=[];network_created=False
    result={'run':run,'status':'failed','qBittorrentImage':h.QBIT_IMAGE,'cases':{},'scope':'owned Docker namespace; no host firewall/Pi changes'}
    with tempfile.TemporaryDirectory(prefix='briani-egress-extended-') as temporary:
        root=pathlib.Path(temporary)
        for role in ('origin','sink','config'):(root/role).mkdir()
        for role in ('origin','sink'):(root/role/'state.json').write_text('{}')
        labels=['--label','org.brianiplayer.fixture=true','--label','org.brianiplayer.run='+run]
        def start(role,*args):
            docker('run','-d','--name',names[role],*labels,*args);owned.append(names[role])
        def inspect(role):return json.loads(docker('inspect',names[role]))[0]
        def events(role):
            path=root/role/'events.jsonl'
            return [json.loads(x) for x in path.read_text().splitlines()] if path.exists() else []
        def state(value):
            new=root/'origin/state.new';new.write_text(json.dumps(value));new.replace(root/'origin/state.json')
        def rules():return [x['rule'] for x in json.loads(docker('exec',names['guard'],'nft','-j','-a','list','chain','inet','briani_egress','output'))['nftables'] if 'rule' in x]
        def count(comment):
            found=[x for x in rules() if x.get('comment')==comment]
            if len(found)!=1:raise RuntimeError('owned per-path counter missing')
            return sum(e['counter']['packets'] for e in found[0]['expr'] if 'counter' in e)
        def add_rule(address,port,comment,action):
            docker('exec',names['guard'],'nft','insert','rule','inet','briani_egress','output',*fixture_rule(address,port,comment,allow=action=='accept'))
        def add_case(label,tracker=None,webseed=None,peer=None):
            info={b'length':16384,b'name':('owned-'+label+'.bin').encode(),b'piece length':16384,b'private':1,b'pieces':hashlib.sha1(bytes(16384)).digest()}
            value={b'info':info}
            if tracker:value[b'announce']=tracker.encode()
            if webseed:value[b'url-list']=[webseed.encode()]
            torrent=root/(label+'.torrent');torrent.write_bytes(h.bencode(value));identity=hashlib.sha1(h.bencode(info)).hexdigest()
            qbit.add_torrent(torrent,'/config/payload');h.wait_for('owned torrent registration',lambda:qbit.json('torrents/info',{'hashes':identity}),15)
            qbit.call('torrents/start',{'hashes':identity})
            if peer:qbit.call('torrents/addPeers',{'hashes':identity,'peers':peer})
            return identity
        def remove(identity):
            qbit.call('torrents/delete',{'hashes':identity,'deleteFiles':'false'})
            h.wait_for('owned torrent removal',lambda:not qbit.json('torrents/info',{'hashes':identity}),10)
        try:
            fixture_id=json.loads(docker('image','inspect',fixture_image))[0]['Id'];result['fixtureImageId']=fixture_id
            result['guardImageId']=json.loads(docker('image','inspect',guard_image))[0]['Id']
            docker('network','create',*labels,network);network_created=True
            for role,ports,dns in [('origin','18080,18105,18106',53),('sink','18100,18101,18102,18103,18104,18105,18106',0)]:
                start(role,'--network',network,'--user',f'{os.getuid()}:{os.getgid()}','--cap-drop=ALL','--read-only','--security-opt','no-new-privileges','--memory','96m','--pids-limit','32',
                    '--mount',f'type=bind,source={root/role},target=/fixture','--mount',f'type=bind,source={FIXTURE},target=/probe_fixture.py,readonly',
                    '--entrypoint','python3',fixture_id,'/probe_fixture.py','--root','/fixture','--ports',ports,'--dns-port',str(dns))
                h.wait_for('owned fixture readiness',lambda:(root/role/'ready').exists(),10)
            origin_ip=inspect('origin')['NetworkSettings']['Networks'][network]['IPAddress'];sink_ip=inspect('sink')['NetworkSettings']['Networks'][network]['IPAddress']
            start('guard','--network',network,'--dns',origin_ip,'--cap-drop=ALL','--cap-add=NET_ADMIN','--security-opt','no-new-privileges','--read-only','--memory','32m','--pids-limit','16',guard_image)
            h.wait_for('owned guard health',lambda:inspect('guard')['State'].get('Health',{}).get('Status')=='healthy',30)
            add_rule(origin_ip,18080,'briani-probe-origin-'+run[:12],'accept')
            # Only this authoritative owned DNS fixture; no LAN/public resolver
            # wildcard is opened. Docker's forwarder can originate this query.
            docker('exec',names['guard'],'nft','insert','rule','inet','briani_egress','output','ip','daddr',origin_ip,'udp','dport','53','counter','accept','comment','briani-probe-owned-dns-'+run[:12])
            guard_ip=inspect('guard')['NetworkSettings']['Networks'][network]['IPAddress']
            start('engine','--network','container:'+names['guard'],'-e',f'PUID={os.getuid()}','-e',f'PGID={os.getgid()}',
                '--mount',f'type=bind,source={root/"config"},target=/config','--memory','256m','--pids-limit','128',h.QBIT_IMAGE)
            def password():
                found=h.TEMP_PASSWORD.search(docker('logs',names['engine']));return found.group(1) if found else None
            secret=h.wait_for('owned temporary engine credential',password,60)
            h.wait_for('owned engine API readiness',lambda:h.qbit_ready(guard_ip),30)
            qbit=h.Qbit('http://'+guard_ip+':8080',secret)
            qbit.call('app/setPreferences',{'json':json.dumps({'dht':False,'pex':False,'lsd':False,'upnp':False,'web_ui_upnp':False,'max_connec':8,'max_connec_per_torrent':4})})
            result['upstreamVersion']=qbit.call('app/version').decode().strip('"');result['upstreamBuildInfo']=qbit.json('app/buildInfo')
            origin_url='http://'+origin_ip+':18080'
            for index,label in enumerate(('tracker','webseed','explicitPeer','trackerRedirect','webseedRedirect','trackerDnsRebind','webseedDnsRebind')):
                print('Running owned egress case: '+label,flush=True);port=18100+index
                docker('exec',names['origin'],'python3','-c','import urllib.request,sys;urllib.request.urlopen("http://"+sys.argv[1]+"/control",timeout=3).read()',sink_ip+':'+str(port))
                baseline_hits=len([x for x in events('sink') if x.get('port')==port]);positive_start=len(events('origin'))
                if label=='explicitPeer':
                    control=add_case(label+'-positive',peer=origin_ip+':18080');predicate=lambda:any(x['type']=='peer' for x in events('origin')[positive_start:])
                elif label.startswith('webseed'):
                    control=add_case(label+'-positive',webseed=origin_url+'/webseed-positive-'+label+'/');predicate=lambda:any(x['type']=='http' and x.get('path','').startswith('/webseed-positive-'+label+'/') for x in events('origin')[positive_start:])
                else:
                    control=add_case(label+'-positive',tracker=origin_url+'/announce-positive-'+label);predicate=lambda:any(x['type']=='http' and x.get('path')=='/announce-positive-'+label for x in events('origin')[positive_start:])
                try:h.wait_for('actual daemon positive '+label,predicate,12);positive=1
                except TimeoutError:positive=0
                remove(control);comment='briani-probe-'+label+'-'+run[:12];add_rule(sink_ip,port,comment,'count')
                target='http://'+sink_ip+':'+str(port);route='/announce-negative-'+label if not label.startswith('webseed') else '/webseed-negative-'+label+'/'
                direct=target+route;dns_name='rebind-'+label.lower()+'-'+run[:8]+'.fixture';phases_ok=True
                if 'Redirect' in label:
                    state({'redirects':{route:direct}});direct=origin_url+route
                elif 'DnsRebind' in label:
                    config={'dnsAnswers':{dns_name:origin_ip}};state(config)
                    add_rule(origin_ip,port,'briani-probe-dns-origin-'+label+'-'+run[:12],'accept')
                    docker('exec',names['guard'],'wget','-q','-T','4','-O','/dev/null','http://'+dns_name+':'+str(port)+'/prevalidation')
                    config['dnsAnswers'][dns_name]=sink_ip;state(config);direct='http://'+dns_name+':'+str(port)+route
                start_events=len(events('origin'))
                negative=add_case(label+'-negative',peer=sink_ip+':'+str(port)) if label=='explicitPeer' else add_case(label+'-negative',**({'webseed':direct} if label.startswith('webseed') else {'tracker':direct}))
                deadline=time.monotonic()+12;packets=0
                while time.monotonic()<deadline:
                    packets=count(comment)
                    if packets:break
                    time.sleep(.25)
                time.sleep(1);hits=len([x for x in events('sink') if x.get('port')==port])-baseline_hits
                if 'Redirect' in label:phases_ok=any(x['type']=='http' and x.get('path','').startswith(route) for x in events('origin')[start_events:])
                elif 'DnsRebind' in label:
                    answers=[x.get('answer') for x in events('origin') if x['type']=='dns' and x.get('name')==dns_name and x.get('qtype')==1]
                    phases_ok=origin_ip in answers and sink_ip in answers
                case={'status':decide(positive,packets,hits,phases_ok=phases_ok),'daemonPositiveObserved':bool(positive),'blockedTcpPackets':packets,'blockedTargetHits':hits,
                    'blockedTargetPositiveControlHits':baseline_hits,'redirectOrDnsPhasesObserved':phases_ok,'isolatedDestinationPort':port}
                if 'DnsRebind' in label:case.update(dnsAnswers=answers,prevalidationClient='owned guard wget; separate daemon resolver')
                result['cases'][label]=case;remove(negative);state({});print(label+': '+case['status'],flush=True)
            result['status']='passed' if all(x['status']=='passed' for x in result['cases'].values()) else 'not_proven'
        except Exception as error:
            result['failure']=type(error).__name__+': '+str(error);raise
        finally:
            for name in reversed(owned):
                record=json.loads(docker('inspect',name))[0]
                if record['Config'].get('Labels',{}).get('org.brianiplayer.run')!=run:raise RuntimeError('cleanup ownership mismatch')
                docker('rm','-f',record['Id'])
            if network_created:
                record=json.loads(docker('network','inspect',network))[0]
                if record.get('Labels',{}).get('org.brianiplayer.run')!=run or record.get('Containers'):raise RuntimeError('network cleanup ownership mismatch')
                docker('network','rm',record['Id'])
            result['cleanup']='exact run-labeled containers/network and owned temporary files removed'
            output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n')
    return 0 if result['status']=='passed' else 1

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,required=True);p.add_argument('--guard-image',default='briani-egress:m10');p.add_argument('--fixture-image',default='briani-vlc-proof:dev');a=p.parse_args();raise SystemExit(probe(a.output,a.guard_image,a.fixture_image))
