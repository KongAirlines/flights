#!/usr/bin/env python3
"""Regression cases for cross-file checks that remain outside native lint."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile

validator = Path(__file__).with_name('validate-api-releases.rb').resolve()
documents = {
    'openapi.yaml': {'info': {'version': '0.2.0-beta.1'}},
    'openapi/versions/0.1.0.yaml': {'info': {'version': '0.1.0'}},
    'konnect/dev.yaml': {'apis': [{'version': '../openapi.yaml#info.version'}]},
    'konnect/dev-versions.yaml': {'apis': [{'versions': [{'version': '../openapi.yaml#info.version', 'spec': '../openapi.yaml'}]}]},
    'konnect/prod.yaml': {'apis': [{'version': '0.1.0', 'versions': [{'version': '../openapi/versions/0.1.0.yaml#info.version', 'spec': '../openapi/versions/0.1.0.yaml'}]}]},
}
with tempfile.TemporaryDirectory(prefix='kongairlines-releases-') as temporary:
    root = Path(temporary)

    def run(*args):
        return subprocess.run(args, cwd=root, text=True, capture_output=True)

    def write(files):
        for name, value in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value))

    write(documents)
    result = run('ruby', str(validator))
    assert result.returncode == 0, result.stderr
    # Use a disposable local Git history, without credentials or signing.
    for args in [('init', '-q'), ('add', '.'), ('-c', 'user.name=Test', '-c', 'user.email=test@example.com', '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'fixture')]:
        result = run('git', *args)
        assert result.returncode == 0, result.stderr
    base = run('git', 'rev-parse', 'HEAD').stdout.strip()
    result = run('ruby', str(validator), base)
    assert result.returncode == 0, result.stderr

    cases = [
        ('wrong release info.version', 'openapi/versions/0.1.0.yaml', {'info': {'version': '0.9.0'}}, 'info.version must match its filename', ''),
        ('wrong current selector', 'konnect/prod.yaml', {'apis': [{'version': '0.9.0', 'versions': []}]}, 'does not exist', ''),
        ('omitted retained release', 'konnect/prod.yaml', {'apis': [{'version': '0.1.0', 'versions': []}]}, 'must retain the paired version/spec', ''),
        ('wrong dev source', 'konnect/dev.yaml', {'apis': [{'version': '0.2.0-beta.1'}]}, 'must select and add', ''),
        ('changed beta without new version', 'openapi.yaml', {'info': {'version': '0.2.0-beta.1', 'description': 'changed'}}, 'changed without advancing', base),
        ('edited retained contract', 'openapi/versions/0.1.0.yaml', {'info': {'version': '0.1.0', 'description': 'changed'}}, 'immutable', base),
    ]
    for name, path, value, expected, comparison in cases:
        files = copy.deepcopy(documents)
        files[path] = value
        write(files)
        result = run('ruby', str(validator), comparison)
        assert result.returncode != 0 and expected in result.stderr, (name, result.stdout, result.stderr)
print('Passed 8 release consistency regression cases')
