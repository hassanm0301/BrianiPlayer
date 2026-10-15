import contextlib,io,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from test_operations import ops

class ComposeSetupTests(unittest.TestCase):
    def test_init_requires_state_and_media_paths(self):
        base=['init','--bind','127.0.0.1','--uid','1000','--gid','1000','--image','fixture']
        for omitted,provided in (('--data',['--state','/mnt/state']),('--state',['--data','/mnt/media'])):
            error=io.StringIO()
            with contextlib.redirect_stderr(error),self.assertRaises(SystemExit) as failure:
                ops.parser().parse_args(base+provided)
            self.assertEqual(failure.exception.code,2)
            self.assertIn(omitted,error.getvalue())
    def test_generated_and_tool_compose_commands_share_project_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory)
            ops.write_compose_files(project)
            manifest=(project/'compose.yaml').read_text()
            calls=[]
            with patch.object(ops,'run',side_effect=lambda argv,**_kwargs:calls.append(argv)):
                ops.compose(project,['ps'])
            name=calls[0][calls[0].index('--project-name')+1]
            self.assertEqual(manifest.splitlines()[0],'name: '+name)
            self.assertIn('${BRIANI_DATA:?',manifest)
            self.assertIn('${BRIANI_STATE:?',manifest)
            self.assertIn('create_host_path: false',manifest)
            self.assertEqual((project/'compose.admin.yaml').read_bytes(),ops.ADMIN.read_bytes())
    def test_custom_manifest_is_preserved_and_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory);manifest=project/'compose.yaml'
            custom='name: '+ops.compose_project_name(project)+'\n# custom deployment\n'
            manifest.write_text(custom)
            ops.write_compose_files(project)
            self.assertEqual(manifest.read_text(),custom)
            manifest.unlink();outside=project/'outside';outside.write_text('preserve')
            manifest.symlink_to(outside)
            with self.assertRaises(ops.OpsError):ops.write_compose_files(project)
            self.assertEqual(outside.read_text(),'preserve')
    def test_conflicting_or_missing_names_cannot_target_another_deployment(self):
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory);manifest=project/'compose.yaml'
            for content in ('name: briani\n','services: {}\n','name: briani\nname: '+ops.compose_project_name(project)+'\n'):
                manifest.write_text(content)
                with self.assertRaisesRegex(ops.OpsError,'retain the deployment name'):ops.write_compose_files(project)
                self.assertEqual(manifest.read_text(),content)

if __name__=='__main__':unittest.main()
