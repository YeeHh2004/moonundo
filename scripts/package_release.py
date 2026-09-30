"""Build a traceable release from a clean Git checkout; only Python stdlib is used."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, subprocess, zipfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=root/'dist')
args = parser.parse_args()
def git(*values):
    return subprocess.check_output(['git', *values], cwd=root)
def digest(data):
    return hashlib.sha256(data).hexdigest()

if git('status', '--porcelain').strip():
    raise SystemExit('Commit source changes before creating a release.')
head = git('rev-parse', 'HEAD').decode().strip()
subprocess.run(['node', 'scripts/build.mjs'], cwd=root, check=True)
info = json.loads((root/'web/build-info.json').read_text(encoding='utf-8'))
assert info['sourceCommit'] == head and info['dirty'] is False, 'Build provenance mismatch'
version = info['version']
files = {}
for entry in git('ls-tree', '-r', '-z', 'HEAD').split(b'\0'):
    if not entry:
        continue
    meta, name = entry.split(b'\t', 1)
    mode, kind, blob = meta.decode().split()
    assert kind == 'blob' and mode != '120000', 'Unexpected symlink or submodule'
    files[name.decode()] = git('cat-file', 'blob', blob)
for name in ['web/moonundo.mjs', 'web/build-info.json', 'web/LICENSE.txt', 'web/THIRD-PARTY-NOTICES.txt']:
    files[name] = (root/name).read_bytes()
assert digest(files['web/moonundo.mjs']) == info['engineSha256']
files['START-HERE.txt'] = f'''MoonUndo {version}
Source commit: {head}
Live demo: https://yeehh2004.github.io/moonundo/
Repository: https://github.com/YeeHh2004/moonundo

Requires Node.js 20+, no npm install for the included demo/CLI:
  node scripts/serve.mjs
  Open http://127.0.0.1:4178
  node cli/moonundo.mjs examples/task-session.json
  node --test tests/*.test.mjs

The compiled MoonBit engine is included. To rebuild, install compiler/core
{info['toolchain']} and run node scripts/build.mjs.
Read README.md, docs/ACCEPTANCE.md, docs/DEVELOPMENT.md and docs/JSON.md.
LICENSE covers original code; licenses/ preserves full upstream notices.
MANIFEST.json identifies source and hashes every other file in this archive.
No .git, credentials, personal submissions, dependencies or local caches included.
'''.encode()
manifest = {'version':version, 'sourceCommit':head, 'toolchain':info['toolchain'],
            'sha256':{name:digest(data) for name,data in sorted(files.items())}}
files['MANIFEST.json'] = (json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
args.output.mkdir(parents=True,exist_ok=True)
archive = args.output/f'MoonUndo-v{version}.zip'
stamp = datetime.fromtimestamp(int(git('show','-s','--format=%ct','HEAD')), timezone.utc)
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as out:
    for name,data in sorted(files.items()):
        item = zipfile.ZipInfo('moonundo/'+name, stamp.timetuple()[:6])
        item.create_system = 3
        item.external_attr = 0o100644 << 16
        item.compress_type = zipfile.ZIP_DEFLATED
        out.writestr(item,data,compresslevel=9)
with zipfile.ZipFile(archive) as out:
    assert out.testzip() is None
    for name,expected in manifest['sha256'].items():
        assert digest(out.read('moonundo/'+name)) == expected, name
print(json.dumps({'archive':str(archive),'sha256':digest(archive.read_bytes()),
                  'sourceCommit':head,'files':len(files)},ensure_ascii=False))
