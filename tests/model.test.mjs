import test from 'node:test';
import assert from 'node:assert/strict';
import {replay,reduce} from '../web/moonundo.mjs';
const run = request => JSON.parse(replay(JSON.stringify(request)));

// Independent stack oracle: stores past and future separately, unlike the library's cursor timeline.
for(let seed=1;seed<=8;seed++)test(`500 generated transitions agree with independent stack model (seed ${seed})`,()=>{
  let random=seed, past=[],future=[],present={id:0,value:0},next=1,saved=0,limit=7;
  const commands=[];
  const pick=n=>{random=(Math.imul(random,1664525)+1013904223)>>>0;return random%n;};
  for(let step=0;step<500;step++){
    const op=pick(7);
    if(op<=1){
      const value=pick(20);commands.push({op:'record',value,label:`edit ${step}`});
      if(value!==present.value){past.push(present);present={id:next++,value};future=[];if(past.length>limit)past.shift();}
    }else if(op===2){commands.push({op:'undo'});if(past.length){future.unshift(present);present=past.pop();}}
    else if(op===3){commands.push({op:'redo'});if(future.length){past.push(present);present=future.shift();}}
    else if(op===4){commands.push({op:'save'});saved=present.id;}
    else if(op===5){commands.push({op:'clear'});past=[];future=[];}
    else{limit=1+pick(9);commands.push({op:'capacity',limit});past=past.slice(-limit);future=future.slice(0,limit-past.length);}
    if(step%20===19){
      const actual=run({initial:0,limit:7,commands});
      assert.equal(actual.ok,true,actual.error);
      assert.equal(actual.state,present.value,`state at step ${step}`);
      assert.equal(actual.undo_depth,past.length);
      assert.equal(actual.redo_depth,future.length);
      assert.equal(actual.dirty,present.id!==saved);
      assert.equal(actual.revision_id,present.id);
      assert.deepEqual(actual.session.revisions.map(r=>r.id),[...past,present,...future].map(r=>r.id));
      const restored=run({session:actual.session,commands:[]});
      assert.deepEqual(restored,actual);
    }
  }
});
test('session rejects fractional, overflowing, duplicate, reversed and out-of-bounds metadata',()=>{
  const valid=run({initial:0,commands:[{op:'record',value:1}]}).session;
  const cases=[];
  for(const key of ['version','limit','cursor','next_id','saved_id'])for(const bad of [0.5,2147483648,-2147483649,'1',false]){
    const copy=structuredClone(valid);copy[key]=bad;cases.push(copy);
  }
  for(const bad of [-1,0.5,2147483648,2]){const copy=structuredClone(valid);copy.revisions[0].id=bad;cases.push(copy);}
  cases.push({...valid,revisions:[]},{...valid,cursor:2},{...valid,version:2},{...valid,next_id:0},{...valid,limit:0});
  for(const session of cases)assert.equal(run({session,commands:[]}).ok,false,JSON.stringify(session));
});
test('revision exhaustion rejects a new edit without wrapping or corrupting restore',()=>{
  const session=run({initial:0,commands:[]}).session;session.next_id=2147483647;
  assert.equal(run({session,commands:[]}).ok,true);
  assert.equal(run({session,commands:[{op:'record',value:1}]}).ok,false);
  assert.equal(run({session,commands:[{op:'begin',label:'x'},{op:'record',value:1},{op:'commit'}]}).ok,false);
});
test('replay rejects unsafe numbers, excessive nesting and overlong scripts',()=>{
  assert.equal(JSON.parse(replay('{"initial":1e999,"commands":[]}')).ok,false);
  assert.equal(run({initial:9007199254740992,commands:[]}).ok,false);
  let initial=0;for(let i=0;i<70;i++)initial=[initial];
  assert.equal(run({initial,commands:[]}).ok,false);
  assert.equal(run({initial:0,commands:Array.from({length:2001},()=>({op:'undo'}))}).ok,false);
});
test('demo import validation rejects fractional identity and position without rounding',()=>{
  for(const [kind,state] of [
    ['tasks',{items:[{id:0.5,title:'bad',done:false}],next_id:1}],
    ['canvas',{shapes:[{id:1,x:0.5,y:0,color:'mint'}],next_id:2}],
    ['tasks',{items:[],next_id:1.5}]
  ])assert.equal(JSON.parse(reduce(JSON.stringify({kind,state,action:{type:'validate'}}))).ok,false);
});
