import json
from pathlib import Path
import subprocess
import tempfile

root = Path('/home/hassan/projects/BrianiPlayer/docs/evidence/M10/polish/server-engine')
results = []
for name in ('adapter', 'metadata'):
    data = json.loads((root / (name + '.json')).read_text())
    run_id = data['runId']
    assert len(run_id) == 32 and all(c in '0123456789abcdef' for c in run_id)
    commands = [
        ['docker', 'ps', '--all', '--quiet', '--filter', 'label=org.briani.test=M05', '--filter', 'label=org.briani.run=' + run_id],
        ['docker', 'network', 'ls', '--quiet', '--filter', 'label=org.briani.test=M05', '--filter', 'label=org.briani.run=' + run_id],
    ]
    outputs = []
    for command in commands:
        result = subprocess.run(command, text=True, capture_output=True, timeout=15)
        if result.returncode:
            raise RuntimeError('Owned-resource query failed: ' + result.stderr[-500:])
        outputs.append(result.stdout.split())
    pattern = ('briani-m05-' if name == 'adapter' else 'briani-m05-peer-') + run_id[:8] + '-*'
    scratch = [str(p) for p in Path(tempfile.gettempdir()).glob(pattern)]
    results.append({'harness': name, 'runId': run_id, 'remainingContainerIds': outputs[0],
                    'remainingNetworkIds': outputs[1], 'remainingScratchPaths': scratch})
evidence = {'readOnlyExactRunLabelQueries': True, 'runs': results,
            'passed': all(not r['remainingContainerIds'] and not r['remainingNetworkIds'] and not r['remainingScratchPaths'] for r in results)}
(root / 'cleanup.json').write_text(json.dumps(evidence, indent=2) + '\n')
print(json.dumps(evidence, indent=2))
raise SystemExit(0 if evidence['passed'] else 1)
