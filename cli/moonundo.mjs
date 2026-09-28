#!/usr/bin/env node
import {readFile} from 'node:fs/promises';
import {replay} from '../web/moonundo.mjs';

const args = process.argv.slice(2);
if (args.length === 1 && ['--help', '-h'].includes(args[0])) {
  console.log('Usage: node cli/moonundo.mjs [script.json|-]\nRead a JSON history script (stdin by default). Emit result/session as JSON.\nExit codes: 0 success, 1 rejected script, 2 usage or I/O error.');
} else if (args.length > 1 || (args[0]?.startsWith('-') && args[0] !== '-')) {
  console.error('Usage: node cli/moonundo.mjs [script.json|-]');
  process.exitCode = 2;
} else {
  try {
    const chunks = [];
    let buffer;
    if (args[0] && args[0] !== '-') buffer = await readFile(args[0]);
    else {
      let size = 0;
      for await (const chunk of process.stdin) {
        size += chunk.length;
        if (size > 8_000_000) throw new Error('Input exceeds 8 MB');
        chunks.push(chunk);
      }
      buffer = Buffer.concat(chunks);
    }
    if (buffer.length > 8_000_000) throw new Error('Input exceeds 8 MB');
    const source = new TextDecoder('utf-8', {fatal: true}).decode(buffer);
    const result = JSON.parse(replay(source));
    console.log(JSON.stringify(result, null, 2));
    if (!result.ok) process.exitCode = 1;
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
  }
}
