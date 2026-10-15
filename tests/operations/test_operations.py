from __future__ import annotations
import importlib.util, json, os, tempfile, unittest
from pathlib import Path
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('briani_operations',ROOT/'tools/operations/briani.py')
ops=importlib.util.module_from_spec(spec); spec.loader.exec_module(ops)

class OperationSafetyTests(unittest.TestCase):
    def setUp(self): self.tmp=tempfile.TemporaryDirectory(); self.root=Path(self.tmp.name)
    def tearDown(self): self.tmp.cleanup()
    def test_env_parser_rejects_unknown_keys_and_shell_syntax_is_never_evaluated(self):
        f=self.root/'.env'; f.write_text('BRIANI_DATA=/srv/a\n')
        self.assertEqual(ops.parse_env(f)['BRIANI_DATA'],'/srv/a')
        f.write_text('SECRET=$(touch /tmp/pwn)\n')
        with self.assertRaises(ops.OpsError): ops.parse_env(f)
    def test_subprocess_invocation_uses_argument_array_without_shell(self):
        fake=type('Result',(),{'returncode':0,'stdout':'ok','stderr':''})()
        with patch.object(ops.subprocess,'run',return_value=fake) as call:
            result=ops.run(['docker','compose','--project-name','name with spaces'],cwd=self.root,capture=True)
        self.assertEqual(result.stdout,'ok')
        self.assertEqual(call.call_args.args[0],['docker','compose','--project-name','name with spaces'])
        self.assertNotIn('shell',call.call_args.kwargs)
    def test_compose_project_name_is_unique_to_project_directory(self):
        captured=[]
        with patch.object(ops,'run',side_effect=lambda argv,**_kwargs: captured.append(argv)):
            ops.compose(self.root/'restore-a',['ps'])
            first=captured[-1][captured[-1].index('--project-name')+1]
            ops.compose(self.root/'restore-b',['ps'])
            second=captured[-1][captured[-1].index('--project-name')+1]
        self.assertNotEqual(first,second)
        self.assertTrue(first.startswith('briani-restore-a-'))
    def test_memory_controller_is_required_and_never_enabled_by_the_tool(self):
        for reported in ('false', '', 'null'):
            with patch.object(ops,'run',return_value=type('R',(),{'stdout':reported})()) as call:
                with self.assertRaisesRegex(ops.OpsError,'cannot enforce'):ops.require_memory_limits(self.root)
                self.assertEqual(call.call_args.args[0],['docker','info','--format','{{json .MemoryLimit}}'])
                self.assertEqual(call.call_count,1)
        with patch.object(ops,'run',return_value=type('R',(),{'stdout':'true\n'})()):ops.require_memory_limits(self.root)
    def test_up_rejects_unenforced_limits_before_compose_mutation(self):
        with patch.object(ops,'context'),patch.object(ops,'run',return_value=type('R',(),{'stdout':'false'})()),patch.object(ops,'compose') as compose:
            with self.assertRaises(ops.OpsError):ops.command_up(type('A',(),{'project':self.root})())
            compose.assert_not_called()
    def test_host_preflight_reports_missing_containment_and_memory_without_mutation(self):
        with patch.object(ops,'run',return_value=type('R',(),{'stdout':'false'})()),patch.object(ops,'kernel_containment_query',return_value={'supported':False,'errno':38}):
            with self.assertRaises(ops.OpsError) as failure:ops.require_host_capabilities(self.root)
            self.assertIn('memory',str(failure.exception));self.assertIn('openat2 BENEATH|NO_SYMLINKS',str(failure.exception))
        with patch.object(ops,'run',return_value=type('R',(),{'stdout':'true'})()),patch.object(ops,'kernel_containment_query',return_value={'supported':True,'errno':None}):
            ops.require_host_capabilities(self.root)
    def test_openat2_probe_uses_read_only_directory_and_containment_flags(self):
        calls=[]
        class FakeSyscall:
            restype=None
            def __call__(self,*args):
                calls.append(args)
                how=args[3]._obj
                self.valid=(how.flags & os.O_ACCMODE == os.O_RDONLY, how.resolve == 0x0c)
                return 99
        class FakeLibc:
            syscall=FakeSyscall()
        with patch.object(ops.platform,'system',return_value='Linux'),patch.object(ops.platform,'machine',return_value='x86_64'),patch.object(ops.os,'open',return_value=12) as opened,patch.object(ops.os,'close') as closed,patch.object(ops.ctypes,'CDLL',return_value=FakeLibc()):
            self.assertEqual(ops.kernel_containment_query(self.root),{'supported':True,'errno':None})
        opened.assert_called_once_with(self.root,os.O_RDONLY|os.O_DIRECTORY|os.O_CLOEXEC)
        self.assertEqual(closed.call_args_list,[unittest.mock.call(99),unittest.mock.call(12)])
        self.assertTrue(calls)
        self.assertEqual(FakeLibc.syscall.valid,(True,True))
    def test_openat2_probe_fails_closed_when_syscall_is_missing_or_flags_unsupported(self):
        for error_number in (38,22):
            class FakeSyscall:
                restype=None
                def __call__(self,*_args):
                    ops.ctypes.set_errno(error_number)
                    return -1
            class FakeLibc:
                syscall=FakeSyscall()
            with self.subTest(errno=error_number),patch.object(ops.platform,'system',return_value='Linux'),patch.object(ops.platform,'machine',return_value='aarch64'),patch.object(ops.os,'open',return_value=12),patch.object(ops.os,'close'),patch.object(ops.ctypes,'CDLL',return_value=FakeLibc()):
                self.assertEqual(ops.kernel_containment_query(self.root),{'supported':False,'errno':error_number})
    def test_image_lock_checks_upstream_pins_and_local_briani_image_id(self):
        lockroot=self.root/'locks'; lockroot.mkdir()
        local_id='sha256:'+'b'*64; qb='lscr.io/linuxserver/qbittorrent@sha256:'+'c'*64; pr='lscr.io/linuxserver/prowlarr@sha256:'+'d'*64
        (lockroot/'toolchain.lock.json').write_text(json.dumps({'images':{'qBittorrent':{'reference':qb},'Prowlarr':{'reference':pr}}}))
        (lockroot/'images.lock.json').write_text(json.dumps({'version':1,'services':{'qbittorrent':{'reference':qb},'prowlarr':{'reference':pr},'briani':{'reference':None,'localImageId':local_id}}}))
        compose=lockroot/'compose.yaml'; compose.write_text(qb+'\n'+pr+'\n')
        with patch.object(ops,'ROOT',lockroot), patch.object(ops,'COMPOSE',compose), patch.object(ops,'run',return_value=type('R',(),{'stdout':local_id+'\n'})()):
            ops.validate_image_lock('briani-server:dev',local=True)
            with self.assertRaises(ops.OpsError): ops.validate_image_lock('registry/briani@sha256:'+'e'*64)
    def test_arm64_local_candidate_uses_native_records_and_only_locked_index_or_config_ids(self):
        lockroot=self.root/'arm-locks';lockroot.mkdir()
        qb='registry/qbit@sha256:'+'a'*64;pr='registry/prowlarr@sha256:'+'b'*64
        api_index='sha256:'+'c'*64;api_config='sha256:'+'d'*64
        guard_index='sha256:'+'e'*64;guard_config='sha256:'+'f'*64
        api={'localTag':'briani-server:arm64','localImageId':api_index,'runtimeConfigDigest':api_config}
        guard={'localTag':'briani-egress:arm64','localImageId':guard_index,'runtimeConfigDigest':guard_config}
        (lockroot/'toolchain.lock.json').write_text(json.dumps({'images':{'qBittorrent':{'reference':qb},'Prowlarr':{'reference':pr}}}))
        (lockroot/'images.lock.json').write_text(json.dumps({'version':1,'services':{'qbittorrent':{'reference':qb},'prowlarr':{'reference':pr},'briani':{'localTag':'briani-server:amd64','localImageId':'sha256:'+'1'*64,'nativeArm64':api},'torrent-egress-guard':{'nativeArm64':guard}}}))
        compose=lockroot/'compose.yaml';compose.write_text(qb+'\n'+pr+'\n')
        with patch.object(ops,'ROOT',lockroot),patch.object(ops,'COMPOSE',compose),patch.object(ops.platform,'machine',return_value='aarch64'):
            for digest in (api_index,api_config):
                with patch.object(ops,'run',return_value=type('R',(),{'stdout':digest})()):ops.validate_image_lock(api['localTag'],local=True)
            with patch.object(ops,'run',return_value=type('R',(),{'stdout':'sha256:'+'0'*64})()):
                with self.assertRaises(ops.OpsError):ops.validate_image_lock(api['localTag'],local=True)
            with self.assertRaises(ops.OpsError):ops.validate_image_lock('briani-server:amd64',local=True)
            for digest in (guard_index,guard_config):
                with patch.object(ops,'run',return_value=type('R',(),{'stdout':digest})()):self.assertEqual(ops.guard_reference(True),guard['localTag'])
            with patch.object(ops,'run',return_value=type('R',(),{'stdout':'sha256:'+'0'*64})()):
                with self.assertRaises(ops.OpsError):ops.guard_reference(True)
            with self.assertRaises(ops.OpsError):ops.local_image_record({'localTag':'amd64-only'})

    def test_init_requires_absolute_nonoverlapping_dedicated_paths_and_pinned_image(self):
        data=self.root/'data'; state=self.root/'state'; project=self.root/'project'
        args=type('A',(),dict(project=project,data=str(data),state=str(state),uid=os.getuid() or 1,gid=os.getgid() or 1,
            minimum_free=1, image='x/y:latest',bind='127.0.0.1',hosts='localhost',replace=False,local_image=False))()
        with self.assertRaises(ops.OpsError): ops.command_init(args)
        args.image='registry.example/briani@sha256:'+'a'*64
        with patch.object(ops,'validate_image_lock'), patch.object(ops,'guard_reference',return_value='fixture-egress@sha256:'+'f'*64):
            ops.command_init(args)
        self.assertFalse((state/'secrets/bootstrap-token').exists())
        self.assertEqual((state/'secrets').stat().st_mode & 0o777,0o700)
        self.assertEqual((project/'.env').stat().st_mode & 0o777,0o600)
    def test_backup_copy_rejects_symlinks(self):
        src=self.root/'src'; dst=self.root/'dst'; src.mkdir(); (src/'safe').write_text('ok')
        (src/'link').symlink_to(self.root)
        with self.assertRaises(ops.OpsError): ops.safe_copy(src,dst)
    def test_restore_verifies_manifest_and_requires_empty_destination(self):
        backup=self.root/'backup'; state=backup/'state'; state.mkdir(parents=True)
        (state/'briani.db').write_text('database')
        (backup/'manifest.json').write_text(json.dumps({'format':1,'mediaIncluded':False,'files':[
            {'path':'briani.db','size':(state/'briani.db').stat().st_size,'sha256':ops.sha_file(state/'briani.db')}]}))
        dest=self.root/'fresh-state'; ops.restore_state(backup,dest)
        self.assertEqual((dest/'briani.db').read_text(),'database')
        with self.assertRaises(ops.OpsError): ops.restore_state(backup,dest)
    def test_restore_rejects_path_traversal_and_tampering(self):
        backup=self.root/'backup'; (backup/'state').mkdir(parents=True)
        (backup/'manifest.json').write_text(json.dumps({'format':1,'mediaIncluded':False,'files':[{'path':'../escape','size':1,'sha256':'x'}]}))
        with self.assertRaises(ops.OpsError): ops.restore_state(backup,self.root/'dest')
        (backup/'state'/'f').write_text('changed')
        (backup/'manifest.json').write_text(json.dumps({'format':1,'mediaIncluded':False,'files':[{'path':'f','size':7,'sha256':'0'*64}]}))
        with self.assertRaises(ops.OpsError): ops.restore_state(backup,self.root/'dest')
    def test_restore_destination_must_differ_from_original_live_state(self):
        backup=self.root/'backup'; backup.mkdir()
        live=self.root/'live-state'; live.mkdir(); data=self.root/'data'; data.mkdir()
        project=self.root/'restore-project'; project.mkdir()
        (backup/'deployment.env').write_text('BRIANI_IMAGE=registry/briani@sha256:'+'a'*64+'\nBRIANI_STATE='+str(live)+'\nBRIANI_DATA='+str(data)+'\nBRIANI_BIND=127.0.0.1\nBRIANI_UID=1\nBRIANI_GID=1\nBRIANI_HOSTS=localhost\n')
        (backup/'manifest.json').write_text(json.dumps({'format':1,'mediaIncluded':False,'files':[]})); (backup/'state').mkdir()
        args=type('A',(),dict(backup=backup,state=live,data=str(data),project=project,allow_existing_data=False))()
        with self.assertRaises(ops.OpsError): ops.command_restore(args)
    def _complete_backup(self):
        backup=self.root/'complete-backup'; state=backup/'state'; (state/'briani').mkdir(parents=True)
        (state/'briani/briani.db').write_text('fixture-db')
        image='registry/briani@sha256:'+'a'*64
        (backup/'deployment.env').write_text(f'BRIANI_IMAGE={image}\nBRIANI_STATE={self.root}/live-state\nBRIANI_DATA={self.root}/original-data\nBRIANI_BIND=127.0.0.1\nBRIANI_UID={os.geteuid()}\nBRIANI_GID={os.getegid()}\nBRIANI_HOSTS=localhost\n')
        for name in ('images.lock.json','toolchain.lock.json'): (backup/name).write_text('{}')
        manifest={'format':1,'mediaIncluded':False,'files':ops.inventory(state),'images':{'brianiDeploymentReference':image},'deploymentEnvSha256':ops.sha_file(backup/'deployment.env'),
            'lockMetadataSha256':{name:ops.sha_file(backup/name) for name in ('images.lock.json','toolchain.lock.json')}}
        (backup/'manifest.json').write_text(json.dumps(manifest))
        return backup
    def test_upgrade_rejects_deleted_backup_database_before_any_docker_call(self):
        backup=self._complete_backup(); (backup/'state/briani/briani.db').unlink(); (self.root/'project').mkdir()
        args=type('A',(),dict(project=self.root/'project',backup=backup,compatibility_file=None,image='registry/new@sha256:'+'b'*64))()
        with patch.object(ops,'context',return_value={'BRIANI_IMAGE':'registry/briani@sha256:'+'a'*64}), patch.object(ops,'compose') as docker:
            with self.assertRaisesRegex(ops.OpsError,'integrity manifest'): ops.command_upgrade(args)
            docker.assert_not_called()
    def test_restore_rejects_live_state_child_and_project_overlap_before_copy(self):
        backup=self._complete_backup(); live=self.root/'live-state'; live.mkdir()
        for dest,project in ((live/'fresh',self.root/'restore-project'),(self.root/'fresh',self.root/'fresh'/'project')):
            args=type('A',(),dict(backup=backup,state=dest,data=str(self.root/'new-media'),project=project,allow_existing_data=False))()
            with patch.object(ops,'validate_image_lock'),patch.object(ops,'restore_state') as copy:
                with self.assertRaises(ops.OpsError): ops.command_restore(args)
                copy.assert_not_called()
            self.assertFalse(dest.exists())
    def test_restore_rejects_different_operator_before_copy(self):
        backup=self._complete_backup()
        args=type('A',(),dict(backup=backup,state=self.root/'fresh',data=str(self.root/'new-media'),project=self.root/'restore-project',allow_existing_data=False))()
        with patch.object(ops.os,'geteuid',return_value=os.geteuid()+1),patch.object(ops,'restore_state') as copy:
            with self.assertRaisesRegex(ops.OpsError,'UID/GID'): ops.command_restore(args)
            copy.assert_not_called()
    def test_upgrade_rejects_other_deployment_backup_before_docker_call(self):
        backup=self._complete_backup(); project=self.root/'other-project'; project.mkdir()
        env=ops.parse_env(backup/'deployment.env'); env['BRIANI_STATE']=str(self.root/'other-state')
        args=type('A',(),dict(project=project,backup=backup,compatibility_file=None,image='registry/new@sha256:'+'b'*64))()
        with patch.object(ops,'context',return_value=env),patch.object(ops,'compose') as docker:
            with self.assertRaisesRegex(ops.OpsError,'deployment identity'): ops.command_upgrade(args)
            docker.assert_not_called()
    def test_upgrade_target_must_current_audited_image_while_context_allows_history(self):
        lockroot=self.root/'history-locks'; lockroot.mkdir()
        old='registry/briani@sha256:'+'a'*64; new='registry/briani@sha256:'+'b'*64
        qb='lscr.io/qbit@sha256:'+'c'*64; pr='lscr.io/prowlarr@sha256:'+'d'*64
        (lockroot/'toolchain.lock.json').write_text(json.dumps({'images':{'qBittorrent':{'reference':qb},'Prowlarr':{'reference':pr}}}))
        (lockroot/'images.lock.json').write_text(json.dumps({'version':1,'services':{'qbittorrent':{'reference':qb},'prowlarr':{'reference':pr},'briani':{'reference':new,'acceptedReferences':[old]}}}))
        compose=lockroot/'compose.yaml'; compose.write_text(qb+'\n'+pr)
        with patch.object(ops,'ROOT',lockroot),patch.object(ops,'COMPOSE',compose):
            ops.validate_image_lock(old); ops.validate_image_lock(new,allow_history=False)
            with self.assertRaises(ops.OpsError): ops.validate_image_lock(old,allow_history=False)
    def test_backup_restarts_exact_services_and_writes_state_manifest(self):
        project=self.root/'project'; project.mkdir()
        state=self.root/'state'; (state/'briani').mkdir(parents=True); (state/'qbittorrent').mkdir(); (state/'prowlarr').mkdir(); (state/'secrets').mkdir(); (state/'briani/db').write_text('db')
        for directory in (state,state/'briani',state/'qbittorrent',state/'prowlarr',state/'secrets'): os.chmod(directory,0o700)
        data=self.root/'data'; data.mkdir()
        digest='a'*64
        (project/'.env').write_text(f'BRIANI_EGRESS_IMAGE=fixture-egress@sha256:{digest}\nBRIANI_IMAGE=registry/briani@sha256:{digest}\nBRIANI_STATE={state}\nBRIANI_DATA={data}\nBRIANI_BIND=127.0.0.1\nBRIANI_UID={os.getuid()}\nBRIANI_GID={os.getgid()}\nBRIANI_HOSTS=localhost\n')
        calls=[]
        def fake_compose(_project,args,**kwargs):
            calls.append(list(args))
            return type('Result',(),{'stdout':'qbittorrent\n' if args[0]=='ps' else ''})()
        output=self.root/'backup'
        with patch.object(ops,'validate_image_lock'), patch.object(ops,'guard_reference',return_value='fixture-egress@sha256:'+digest), patch.object(ops,'compose',side_effect=fake_compose):
            ops.command_backup(type('A',(),{'project':project,'output':output})())
        self.assertEqual(calls[1],['stop',*ops.SERVICES])
        self.assertEqual(calls[-1],['start','qbittorrent'])
        manifest=json.loads((output/'manifest.json').read_text())
        self.assertEqual(manifest['files'][0]['sha256'],ops.sha_file(output/'state/briani/db'))

if __name__=='__main__': unittest.main()
