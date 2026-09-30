import {mkdtempSync, cpSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../',import.meta.url)).replaceAll('\\','/');
const workspace=mkdtempSync(join(tmpdir(),'moonundo-consumer-'));
const consumer=join(workspace,'consumer');
try {
  cpSync(new URL('../examples/consumer/',import.meta.url),consumer,{recursive:true,filter:source=>!/[\\/](_build|\.mooncakes)([\\/]|$)/.test(source)});
  const {version}=JSON.parse(readFileSync(new URL('../package.json',import.meta.url),'utf8'));
  assert.ok(readFileSync(join(consumer,'moon.mod'),'utf8').includes(`YeeHh2004/moonundo@${version}`),'example dependency must match the release');
  writeFileSync(join(workspace,'moon.work'),`members = [\n  ${JSON.stringify(root)},\n  "consumer",\n]\n`);
  const run=args=>execFileSync('moon',args,{cwd:consumer,stdio:'inherit'});
  run(['fmt','--check']);
  for(const target of ['js','wasm-gc']) {
    run(['test','--target',target]);
    run(['run','.','--target',target]);
  }
  console.log('Standalone document consumer passed on JS and Wasm GC: nested transactions, deep copy, typed codecs, savepoint/redo restore, invalid schema and branching.');
} finally {
  // Only remove the unique directory created by this process under the OS temp root.
  assert.equal(dirname(resolve(workspace)),resolve(tmpdir()));
  rmSync(workspace,{recursive:true,force:true});
}
