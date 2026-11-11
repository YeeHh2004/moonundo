import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('published web build contains licenses and complete upstream notices',()=>{
  assert.equal(read('web/LICENSE.txt'),read('LICENSE').replaceAll('\r\n','\n'));
  const served=read('web/THIRD-PARTY-NOTICES.txt');
  const info=JSON.parse(read('web/build-info.json'));
  const header='upstream notices reproduced in full.\n\n';
  const separator='\n\nMoonBit core license:\n';
  assert.ok(served.indexOf(header)>=0);
  const start=served.indexOf(header)+header.length;
  const end=served.lastIndexOf(separator);
  assert.ok(end>start,'full upstream notice and license sections are present');
  assert.equal(createHash('sha256').update(served.slice(start,end)).digest('hex'),info.coreNoticeSha256);
  assert.equal(createHash('sha256').update(served.slice(end+separator.length)).digest('hex'),info.coreLicenseSha256);
});
test('build metadata identifies the exact engine bytes and matches module version',()=>{
  const info=JSON.parse(read('web/build-info.json'));
  const pkg=JSON.parse(read('package.json'));
  assert.equal(info.version,pkg.version);
  assert.ok(read('moon.mod').includes(`version = "${info.version}"`));
  assert.match(info.toolchain,/^\d+\.\d+\.\d+(?:[-+]\S+)?$/);
  assert.match(info.compilerVersion,new RegExp(`^(?:moonc )?v${info.toolchain.replaceAll('.','\\.').replaceAll('+','\\+')}(?: |$)`));
  assert.ok(info.coreVersion.length>0);
  assert.ok(info.moonVersion.includes(info.toolchain));
  assert.equal(info.engineSha256,createHash('sha256').update(read('web/moonundo.mjs')).digest('hex'));
});
