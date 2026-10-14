import importlib.util
import pathlib
import re
import shlex
import subprocess
import sys
from unittest.mock import patch

root = pathlib.Path(__file__).resolve().parents[4]
files = ['README.md', 'docs/operations/README.md', 'docs/operations/advanced.md', 'docs/client-installation.md',
         'docs/user-guide.md', 'client/README.md']
links = blocks = commands = 0
for name in files:
    path = root / name
    content = path.read_text()
    assert content.count('```') % 2 == 0, name
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', content):
        if '://' in target or target.startswith('#'):
            continue
        local, _, anchor = target.partition('#')
        resolved = (path.parent / local).resolve()
        assert resolved.exists(), f'{name}: missing {target}'
        if anchor:
            headings = re.findall(r'^#+ (.+)$', resolved.read_text(), re.M)
            slugs = [re.sub(r'[^\w\- ]', '', h.lower()).replace(' ', '-') for h in headings]
            assert anchor in slugs, f'{name}: missing anchor {target}'
        links += 1
    for shell in re.findall(r'```(?:bash|sh)\n(.*?)\n```', content, re.S):
        result = subprocess.run(['bash', '-n'], input=shell, text=True, capture_output=True)
        assert result.returncode == 0, f'{name}: {result.stderr}'
        blocks += 1

spec = importlib.util.spec_from_file_location('ops', root / 'tools/operations/briani.py')
ops = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ops)
advanced = (root / 'docs/operations/advanced.md').read_text()
operations = (root / 'docs/operations/README.md').read_text() + '\n' + advanced
values = {'BRIANI_PACKAGE': str(root), 'BRIANI_PROJECT': '/home/you/briani/ops',
          'BRIANI_STATE_DIR': '/mnt/briani-ssd/state', 'BRIANI_MEDIA_DIR': '/mnt/briani-ssd/media',
          'BRIANI_SERVER_IP': '192.168.1.50', 'BRIANI_SERVER_IMAGE': 'briani-server:m10'}
for shell in re.findall(r'```bash\n(.*?)\n```', operations, re.S):
    shell = shell.replace('\\\n', '')
    for line in shell.splitlines():
        if not line.startswith('python3 "$BRIANI_PACKAGE/tools/operations/briani.py" '):
            continue
        for key, value in values.items():
            line = line.replace('$' + key, value)
        line = line.replace('$(id -u)', '1000').replace('$(id -g)', '1000')
        ops.parser().parse_args(shlex.split(line)[2:])
        commands += 1

helper = re.search(r'BRIANI_COMPOSE_PROJECT=.*?<<\'PY\'\n(.*?)\nPY', advanced, re.S).group(1)
for project in ['/home/you/briani/ops', '/tmp/A project with spaces', '/tmp/!!!', '/tmp/very-long-project-directory-name-for-restore']:
    result = subprocess.run([sys.executable, '-', project], input=helper, text=True,
                            capture_output=True, check=True)
    recorded = []
    with patch.object(ops, 'run', side_effect=lambda argv, **kwargs: recorded.append(argv)):
        ops.compose(pathlib.Path(project), ['ps'])
    actual = recorded[0][recorded[0].index('--project-name') + 1]
    assert result.stdout.strip() == actual, (project, result.stdout, actual)

print(f'PASS: {len(files)} documents; {links} local links/anchors; {blocks} shell blocks; '
      f'{commands} operations commands accepted by current parser; 4 Compose identity comparisons.')
