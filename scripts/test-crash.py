#!/usr/bin/env python3
"""Kill only this test's own child, then recover its disposable workspace."""
from pathlib import Path
import os
import select
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
binary = root / '.test-build/ui/validate'
if not binary.exists():
    raise SystemExit('Run bash scripts/test-ui.sh first on macOS.')
with tempfile.TemporaryDirectory(prefix='sqlgarden-crash-') as directory:
    env = os.environ.copy()
    env['SQLGARDEN_CRASH_TEST_DIR'] = directory
    for prefix in ('/opt/homebrew', '/usr/local'):
        library = Path(prefix) / 'opt/openssl@3/lib'
        if (library / 'libssl.3.dylib').exists():
            env['DYLD_LIBRARY_PATH'] = str(library)
            break
    child = subprocess.Popen([str(binary), '--crash-write'], cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        if not select.select([child.stdout], [], [], 15)[0] or child.stdout.readline().strip() != 'CRASH_READY':
            raise RuntimeError('Writer did not confirm autosave')
        child.kill()  # SIGKILL: no application termination callback can flush state.
        child.wait(timeout=10)
        subprocess.run([str(binary), '--crash-read'], cwd=root, env=env, check=True)
    finally:
        if child.poll() is None:
            child.kill()
            child.wait(timeout=10)
