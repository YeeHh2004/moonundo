import {execFileSync} from 'node:child_process';
import {readdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const run=(binary,args)=>execFileSync(binary,args,{cwd:root,stdio:'inherit'});
run('moon',['version','--all']);
run('moon',['fmt','--check']);
for(const target of ['js','wasm-gc']) {
  run('moon',['check','--target',target,'--deny-warn']);
  run('moon',['build','--target',target,'--deny-warn']);
  run('moon',['test','--target',target,'--deny-warn']);
  run('moon',['run','examples/typed','--target',target]);
}
run(process.execPath,['scripts/build.mjs']);
const tests=readdirSync(new URL('../tests/',import.meta.url)).filter(f=>f.endsWith('.test.mjs')).sort().map(f=>'tests/'+f);
run(process.execPath,['--test',...tests]);
run(process.execPath,['scripts/check-consumer.mjs']);
if(process.argv.includes('--browser'))run(process.execPath,['tests/browser.mjs']);
console.log('MoonUndo verification completed successfully.');
