import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {replay, reduce} from '../web/moonundo.mjs';
const root = fileURLToPath(new URL('../', import.meta.url));
const cli = (args = [], input = '') => spawnSync(process.execPath, ['cli/moonundo.mjs', ...args], {cwd: root, input, encoding: 'utf8'});

test('CLI replays fixture and preserves clean transaction boundary', () => {
  const r = cli(['examples/task-session.json']);
  assert.equal(r.status, 0, r.stderr);
  const result = JSON.parse(r.stdout);
  assert.equal(result.state.items.length, 2);
  assert.equal(result.undo_depth, 1);
  assert.equal(result.dirty, false);
  assert.equal(result.undo_label, 'Add two tasks');
  assert.equal(result.redo_label, null);
});
test('CLI accepts stdin and round-trips exported session', () => {
  const first = JSON.parse(cli([], JSON.stringify({initial: 0, commands: [{op:'record',value:5}]})).stdout);
  const second = cli(['-'], JSON.stringify({session:first.session, commands:[{op:'undo'}]}));
  assert.equal(second.status, 0, second.stderr);
  const result = JSON.parse(second.stdout);
  assert.equal(result.state, 0);
  assert.equal(result.undo_label, null);
  assert.equal(result.redo_label, 'Edit');
});
test('CLI distinguishes script rejection, usage and I/O failures', () => {
  assert.equal(cli([], '{bad').status, 1);
  assert.equal(cli(['--wrong']).status, 2);
  assert.equal(cli(['missing-file.json']).status, 2);
  assert.equal(cli([], Buffer.from([0xff])).status, 2);
  assert.equal(cli(['--help']).status, 0);
});
test('compiled reducer and history interoperate for ordinary application state', () => {
  const initial = {items:[], next_id:1};
  const next = JSON.parse(reduce(JSON.stringify({kind:'tasks',state:initial,action:{type:'add',title:'Ship'}})));
  assert.equal(next.ok, true);
  const result = JSON.parse(replay(JSON.stringify({initial,commands:[{op:'record',value:next.state,label:'Add task'},{op:'undo'},{op:'redo'}]})));
  assert.deepEqual(result.state.items, [{id:1,title:'Ship',done:false}]);
  assert.equal(result.undo_depth, 1);
});
