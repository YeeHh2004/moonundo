import {execFileSync} from 'node:child_process';
import {mkdirSync, copyFileSync, readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {homedir} from 'node:os';
import {join} from 'node:path';
const root = fileURLToPath(new URL('../', import.meta.url));
const installed = execFileSync('moon', ['version', '--all'], {cwd:root,encoding:'utf8'});
const compilerVersion = execFileSync('moonc', ['-v'], {cwd:root,encoding:'utf8'}).trim();
const toolchain = /^(?:moonc )?v(\S+)/.exec(compilerVersion)?.[1];
if (!toolchain) throw new Error(`Cannot identify the active MoonBit compiler: ${compilerVersion}`);
const core = join(process.env.MOON_HOME || join(homedir(),'.moon'),'lib','core');
const coreVersion = /^version\s*=\s*"([^"]+)"/m.exec(readFileSync(join(core,'moon.mod'),'utf8'))?.[1];
if (!coreVersion) throw new Error(`Cannot identify the active MoonBit core in ${core}`);
const readCore = name => readFileSync(join(core,name),'utf8').replaceAll('\r\n','\n');
const coreNotice = readCore('NOTICE');
const coreLicense = readCore('LICENSE');
const hash = text => createHash('sha256').update(text).digest('hex');
console.log(installed.trim());
// Compatibility is established by compilation and tests, not by rejecting a
// compiler whose version differs from the reproducible CI baseline.
execFileSync('moon', ['build', '--target', 'js', '--release', '--deny-warn'], {cwd: root, stdio: 'inherit'});
mkdirSync(new URL('../web/', import.meta.url), {recursive: true});
copyFileSync(new URL('../_build/js/release/build/bridge/bridge.js', import.meta.url), new URL('../web/moonundo.mjs', import.meta.url));
const readText=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8').replaceAll('\r\n','\n');
writeFileSync(new URL('../web/LICENSE.txt', import.meta.url),readText('LICENSE'));
const notices = 'MoonUndo: Copyright 2026 YeeHh2004 and contributors. Apache-2.0.\n\n'
  + 'MoonBit compiler '+toolchain+'; core '+coreVersion+': upstream notices reproduced in full.\n\n'
  + coreNotice
  + '\n\nMoonBit core license:\n'+coreLicense;
writeFileSync(new URL('../web/THIRD-PARTY-NOTICES.txt',import.meta.url),notices);
let sourceCommit=null, dirty=null;
try {
  sourceCommit=execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim();
  dirty=!!execFileSync('git',['status','--porcelain','--untracked-files=no'],{cwd:root,encoding:'utf8'}).trim();
} catch {} // Source ZIP rebuilds may not have a .git directory.
const {version}=JSON.parse(readFileSync(new URL('../package.json',import.meta.url),'utf8'));
const engineSha256=createHash('sha256').update(readFileSync(new URL('../web/moonundo.mjs',import.meta.url))).digest('hex');
writeFileSync(new URL('../web/build-info.json',import.meta.url),JSON.stringify({version,sourceCommit,dirty,toolchain,compilerVersion,coreVersion,moonVersion:installed.trim(),coreNoticeSha256:hash(coreNotice),coreLicenseSha256:hash(coreLicense),engineSha256},null,2)+'\n');
console.log('Built web/moonundo.mjs from MoonBit sources');
