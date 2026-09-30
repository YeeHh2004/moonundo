import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('published web build contains licenses and complete upstream notices',()=>{
  assert.equal(read('web/LICENSE.txt'),read('LICENSE').replaceAll('\r\n','\n'));
  const served=read('web/THIRD-PARTY-NOTICES.txt');
  assert.ok(served.includes(read('licenses/MoonBit-core-NOTICE').replaceAll('\r\n','\n')));
  assert.ok(served.includes(read('licenses/MoonBit-core-LICENSE').replaceAll('\r\n','\n')));
});
test('build metadata identifies the exact engine bytes and matches module version',()=>{
  const info=JSON.parse(read('web/build-info.json'));
  const pkg=JSON.parse(read('package.json'));
  assert.equal(info.version,pkg.version);
  assert.ok(read('moon.mod').includes(`version = "${info.version}"`));
  assert.equal(info.toolchain,'0.10.14+7d59c7ec9');
  assert.equal(info.engineSha256,createHash('sha256').update(read('web/moonundo.mjs')).digest('hex'));
});
