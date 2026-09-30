import {mkdtempSync, cpSync, writeFileSync, readFileSync, readdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../',import.meta.url)).replaceAll('\\','/');
const workspace=mkdtempSync(join(tmpdir(),'moonundo-consumer-'));
const consumer=join(workspace,'consumer');
const registry=process.argv.includes('--registry');
try {
  cpSync(new URL('../examples/consumer/',import.meta.url),consumer,{recursive:true,filter:source=>!/[\\/](_build|\.mooncakes)([\\/]|$)/.test(source)});
  const {version}=JSON.parse(readFileSync(new URL('../package.json',import.meta.url),'utf8'));
  assert.ok(readFileSync(join(consumer,'moon.mod'),'utf8').includes(`YeeHh2004/moonundo@${version}`),'example dependency must match the release');
  const run=args=>execFileSync('moon',args,{cwd:consumer,stdio:'inherit'});
  if(registry) {
    // No workspace or path dependency: resolution must use the public registry.
    run(['update']);
    run(['add',`YeeHh2004/moonundo@${version}`]);
    run(['build','--target','js']);
    run(['tree']);
    const dependency=join(consumer,'.mooncakes','YeeHh2004','moonundo','moon.mod');
    const published=readFileSync(dependency,'utf8');
    assert.match(published,new RegExp(`version\\s*=\\s*"${version.replaceAll('.','\\.')}"`),'registry installed version must match');
    const normalize=text=>text.replaceAll('\r\n','\n');
    for(const source of readdirSync(root).filter(name=>name.endsWith('.mbt')||name.endsWith('.mbti'))) {
      assert.equal(normalize(readFileSync(join(dirname(dependency),source),'utf8')),normalize(readFileSync(join(root,source),'utf8')),`published source must match repository: ${source}`);
    }
    console.log(`Verified registry dependency YeeHh2004/moonundo@${version}.`);
  } else {
    writeFileSync(join(workspace,'moon.work'),`members = [\n  ${JSON.stringify(root)},\n  "consumer",\n]\n`);
  }
  run(['fmt','--check']);
  for(const target of ['js','wasm-gc']) {
    run(['test','--target',target]);
    run(['run','.','--target',target]);
  }
  console.log(`${registry?'Registry-installed':'Workspace'} document consumer passed on JS and Wasm GC: nested transactions, deep copy, typed codecs, savepoint/redo restore, invalid schema and branching.`);
} finally {
  // Only remove the unique directory created by this process under the OS temp root.
  assert.equal(dirname(resolve(workspace)),resolve(tmpdir()));
  rmSync(workspace,{recursive:true,force:true});
}
