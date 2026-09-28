import {execFileSync} from 'node:child_process';
import {mkdirSync, copyFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
execFileSync('moon', ['build', '--target', 'js', '--release'], {cwd: root, stdio: 'inherit'});
mkdirSync(new URL('../web/', import.meta.url), {recursive: true});
copyFileSync(new URL('../_build/js/release/build/bridge/bridge.js', import.meta.url), new URL('../web/moonundo.mjs', import.meta.url));
console.log('Built web/moonundo.mjs from MoonBit sources');
