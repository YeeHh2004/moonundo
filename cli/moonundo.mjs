#!/usr/bin/env node
import {createReadStream, readFileSync} from 'node:fs';

const args = process.argv.slice(2);
if (args.length === 1 && ['--help', '-h'].includes(args[0])) {
  console.log('Usage: node cli/moonundo.mjs [script.json|-|--version]\nRead a JSON history script (stdin by default). Emit result/session as JSON.\nInput limit: 8 MB UTF-8; replay limit: 2 million UTF-16 units, 2000 commands.\nExit codes: 0 success, 1 rejected script, 2 usage or I/O error.');
} else if (args.length === 1 && args[0] === '--version') {
  const {version} = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
  console.log(`MoonUndo ${version}`);
} else if (args.length > 1 || (args[0]?.startsWith('-') && args[0] !== '-')) {
  console.error('Usage: node cli/moonundo.mjs [script.json|-]');
  process.exitCode = 2;
} else {
  try {
    const chunks = [];
    const input = args[0] && args[0] !== '-' ? createReadStream(args[0]) : process.stdin;
    let size = 0;
    for await (const chunk of input) {
      size += chunk.length;
      if (size > 8_000_000) throw new Error('Input exceeds 8 MB');
      chunks.push(chunk);
    }
    const buffer = Buffer.concat(chunks, size);
    const source = new TextDecoder('utf-8', {fatal: true}).decode(buffer);
    let replay;
    try { ({replay} = await import('../web/moonundo.mjs')); }
    catch (error) {
      if (error.code === 'ERR_MODULE_NOT_FOUND') throw new Error('Compiled engine missing. Run node scripts/build.mjs or use the precompiled release ZIP.');
      throw error;
    }
    const result = JSON.parse(replay(source));
    console.log(JSON.stringify(result, null, 2));
    if (!result.ok) process.exitCode = 1;
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
  }
}
