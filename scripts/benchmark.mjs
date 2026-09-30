import {performance} from 'node:perf_hooks';
import {platform, arch} from 'node:os';
import assert from 'node:assert/strict';
import {replay,open_editor,dispatch_editor,close_editor} from '../web/moonundo.mjs';
const count=1000;
const commands=Array.from({length:count},(_,i)=>({op:'record',value:i+1,group:'drag'}));
function fullReplay(){
  let output;
  for(let i=1;i<=count;i++)output=JSON.parse(replay(JSON.stringify({initial:0,limit:50,commands:commands.slice(0,i)})));
  return output;
}
function incremental(){
  const opened=JSON.parse(open_editor('{"initial":0,"limit":50}'));
  assert.equal(opened.ok,true);
  try{
    let output;
    for(const command of commands)output=JSON.parse(dispatch_editor(opened.handle,JSON.stringify(command)));
    return output;
  }finally{close_editor(opened.handle);}
}
const trials=[];
fullReplay();incremental(); // Warm up both paths before collecting timings.
for(let i=0;i<3;i++){
  const start=performance.now(), old=fullReplay(), middle=performance.now(), current=incremental(), end=performance.now();
  assert.deepEqual(current,old);
  assert.equal(current.state,1000);assert.equal(current.undo_depth,1);
  trials.push({fullReplayMs:middle-start,incrementalMs:end-middle});
}
const median=key=>trials.map(x=>x[key]).sort((a,b)=>a-b)[1];
console.log(JSON.stringify({node:process.version,platform:platform(),arch:arch(),operations:count,trials,
  medianMs:{fullReplay:median('fullReplayMs'),incremental:median('incrementalMs')},
  note:'Illustrative adapter benchmark, not a universal performance guarantee. Both produce identical final states and history.'},null,2));
