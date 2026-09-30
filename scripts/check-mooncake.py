"""Inspect exactly what moon publish will distribute; never uploads or reads credentials."""
from pathlib import Path
import hashlib, json, subprocess, zipfile

root = Path(__file__).resolve().parent.parent
version = json.loads((root/'package.json').read_text(encoding='utf-8'))['version']
subprocess.run(['moon', 'package'], cwd=root, check=True)
archive = root/'_build/publish'/f'YeeHh2004-moonundo-{version}.zip'
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    names = set(z.namelist())
    required = {'moon.mod', 'moon.pkg', 'pkg.generated.mbti', 'history.mbt',
                'LICENSE', 'NOTICE.md', 'licenses/MoonBit-core-LICENSE',
                'licenses/MoonBit-core-NOTICE', 'docs/MOONCAKES.md',
                'examples/typed/main.mbt', 'portability_test.mbt'}
    assert required <= names, f'Missing required files: {required - names}'
    for name in names:
        path = Path(name)
        assert not path.is_absolute() and '..' not in path.parts, name
        assert not any(part in {'.git', '.moon', '.mooncakes', 'node_modules', '_build', 'dist'} for part in path.parts), name
        assert path.name != 'credentials.json', name
        assert not name.startswith(('web/', 'scripts/', 'tests/', 'bridge/', 'cli/', 'examples/consumer/')), name
        assert path.suffix not in {'.js', '.mjs', '.py', '.zip'}, name
    manifest = z.read('moon.mod').decode()
    assert f'version = "{version}"' in manifest
    assert 'license = "Apache-2.0"' in manifest
print(json.dumps({'version': version, 'archive': str(archive.relative_to(root)),
                  'files': len(names), 'bytes': archive.stat().st_size,
                  'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
                  'implementation': 'MoonBit sources only; licenses and runnable typed example included'}, indent=2))
