import test from 'node:test';
import assert from 'node:assert/strict';
import {open_editor,dispatch_editor,close_editor,replay,reduce} from '../web/moonundo.mjs';
const open = initial => {
  const result=JSON.parse(open_editor(JSON.stringify({initial,limit:8})));
  assert.equal(result.ok,true,result.error);return result.handle;
};
const send=(id,command)=>JSON.parse(dispatch_editor(id,JSON.stringify(command)));

test('incremental history agrees with replay including nested transactions, grouping and saves',()=>{
  const id=open(0), commands=[];
  try{
    for(const command of [
      {op:'record',value:1,group:'a'}, {op:'record',value:2,group:'a'}, {op:'save'},
      {op:'begin',label:'outer'}, {op:'record',value:3}, {op:'begin',label:'inner'},
      {op:'record',value:4}, {op:'rollback'}, {op:'commit'}, {op:'undo'},
      {op:'redo'}, {op:'record',value:5}, {op:'capacity',limit:2}, {op:'undo'}
    ]){
      commands.push(command);
      assert.deepEqual(send(id,command),JSON.parse(replay(JSON.stringify({initial:0,limit:8,commands}))));
    }
  }finally{close_editor(id);}
});
test('more than 2000 edits retain one explicit group, and a long transaction remains cancellable',()=>{
  const id=open(0);
  try{
    let result;
    for(let i=1;i<=2300;i++)result=send(id,{op:'record',value:i,group:'drag'});
    assert.equal(result.state,2300);assert.equal(result.undo_depth,1);
    send(id,{op:'begin',label:'long preview'});
    for(let i=1;i<=2300;i++)result=send(id,{op:'record',value:3000+i});
    assert.equal(result.transaction_depth,1);
    assert.equal(send(id,{op:'rollback'}).state,2300);
    assert.equal(send(id,{op:'undo'}).state,0);
  }finally{close_editor(id);}
});
test('saving can fail without marking live state clean; successful prepare then save round-trips',()=>{
  const id=open({count:0});
  try{
    send(id,{op:'record',value:{count:1},group:'edit'});
    const before=send(id,{op:'status'}), prepared=send(id,{op:'prepare_save'});
    assert.equal(before.dirty,true);assert.deepEqual(send(id,{op:'status'}),before);
    const restored=JSON.parse(open_editor(JSON.stringify({session:prepared.session})));
    try{assert.equal(send(restored.handle,{op:'status'}).dirty,false);}finally{close_editor(restored.handle);}
    assert.equal(send(id,{op:'save'}).dirty,false);
    assert.equal(send(id,{op:'undo'}).dirty,true);
    assert.equal(send(id,{op:'redo'}).dirty,false);
  }finally{close_editor(id);}
});
test('registry bounds active editors, releases capacity and never reuses stale handles',()=>{
  const ids=[];
  try{
    for(let i=0;i<64;i++)ids.push(open(i));
    assert.equal(JSON.parse(open_editor('{"initial":0}')).ok,false);
    const old=ids.pop();assert.equal(close_editor(old),true);assert.equal(close_editor(old),false);
    const replacement=open(999);ids.push(replacement);
    assert.notEqual(replacement,old);assert.equal(send(old,{op:'undo'}).ok,false);
    assert.equal(send(ids[0],{op:'status'}).state,0);
  }finally{ids.forEach(close_editor);}
});

test('adapters expose actionable error details instead of only exception type names',()=>{
  assert.match(JSON.parse(replay('{"initial":0,"commands":[{"op":"unknown"}]}')).error,/unknown operation: unknown/);
  assert.match(JSON.parse(open_editor('{"initial":0,"limit":0}')).error,/limit must be between/);
  const id=open(0);
  try{
    assert.match(send(id,{op:'record'}).error,/missing field: value/);
    assert.match(send(id,{op:'record',value:1,group:false}).error,/String|string/);
  }finally{close_editor(id);}
  assert.match(JSON.parse(reduce(JSON.stringify({kind:'tasks',state:{items:[],next_id:1},action:{type:'add',title:' '}}))).error,/enter a task title/);
});
