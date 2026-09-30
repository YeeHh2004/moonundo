import {execFileSync} from 'node:child_process';
import {mkdirSync, copyFileSync, readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root = fileURLToPath(new URL('../', import.meta.url));
const toolchain = '0.10.14+7d59c7ec9';
const installed = execFileSync('moon', ['version', '--all'], {cwd:root,encoding:'utf8'});
if (!installed.includes(toolchain)) throw new Error(`Use the pinned MoonBit toolchain ${toolchain}. See docs/DEVELOPMENT.md.`);
execFileSync('moon', ['build', '--target', 'js', '--release'], {cwd: root, stdio: 'inherit'});
mkdirSync(new URL('../web/', import.meta.url), {recursive: true});
copyFileSync(new URL('../_build/js/release/build/bridge/bridge.js', import.meta.url), new URL('../web/moonundo.mjs', import.meta.url));
const readText=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8').replaceAll('\r\n','\n');
writeFileSync(new URL('../web/LICENSE.txt', import.meta.url),readText('LICENSE'));
const notices = 'MoonUndo: Copyright 2026 YeeHh2004 and contributors. Apache-2.0.\n\n'
  + 'MoonBit core (pinned '+toolchain+'): upstream notices reproduced in full.\n\n'
  + readText('licenses/MoonBit-core-NOTICE')
  + '\n\nMoonBit core license:\n'+readText('licenses/MoonBit-core-LICENSE');
writeFileSync(new URL('../web/THIRD-PARTY-NOTICES.txt',import.meta.url),notices);
let sourceCommit=null, dirty=null;
try {
  sourceCommit=execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim();
  dirty=!!execFileSync('git',['status','--porcelain','--untracked-files=no'],{cwd:root,encoding:'utf8'}).trim();
} catch {} // Source ZIP rebuilds may not have a .git directory.
const {version}=JSON.parse(readFileSync(new URL('../package.json',import.meta.url),'utf8'));
const engineSha256=createHash('sha256').update(readFileSync(new URL('../web/moonundo.mjs',import.meta.url))).digest('hex');
writeFileSync(new URL('../web/build-info.json',import.meta.url),JSON.stringify({version,sourceCommit,dirty,toolchain,engineSha256},null,2)+'\n');
console.log('Built web/moonundo.mjs from MoonBit sources');
