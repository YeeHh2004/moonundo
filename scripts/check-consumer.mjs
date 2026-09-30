import {mkdtempSync, mkdirSync, writeFileSync, readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
const root=fileURLToPath(new URL('../',import.meta.url)).replaceAll('\\','/');
const workspace=mkdtempSync(join(tmpdir(),'moonundo-consumer-'));
const consumer=join(workspace,'consumer');mkdirSync(consumer);
writeFileSync(join(workspace,'moon.work'),`members = [${JSON.stringify(root)}, "consumer"]\n`);
const {version}=JSON.parse(readFileSync(new URL('../package.json',import.meta.url),'utf8'));
writeFileSync(join(consumer,'moon.mod'),`name = "acceptance/consumer"\nimport { "YeeHh2004/moonundo@${version}" }\n`);
writeFileSync(join(consumer,'moon.pkg'),'import { "YeeHh2004/moonundo" @undo }\n');
writeFileSync(join(consumer,'consumer.mbt'),`///|
pub fn create() -> @undo.History[Array[Int]] {
  @undo.History::new([1], copy=fn(a) { a.copy() }, equal=fn(a,b) { a == b }).unwrap()
}
`);
writeFileSync(join(consumer,'integration_test.mbt'),`///|
test "separate module imports public generic history" {
  let h = @consumer.create()
  ignore(h.begin("batch"))
  ignore(h.record([1,2], "first"))
  ignore(h.record([1,2,3], "second"))
  ignore(h.commit())
  assert_eq(h.undo_depth(), 1)
  ignore(h.undo())
  assert_eq(h.state(), [1])
  ignore(h.redo())
  assert_eq(h.state(), [1,2,3])
}
`);
for(const target of ['js','wasm-gc'])execFileSync('moon',['test','--target',target],{cwd:consumer,stdio:'inherit'});
console.log('Separate-module consumer passed on JS and Wasm GC.');
