import test from 'node:test';
import assert from 'node:assert/strict';
import {open_editor,dispatch_editor,close_editor,replay,reduce} from '../web/moonundo.mjs';
const open = initial => {
  const result=JSON.parse(open_editor(JSON.stringify({initial,limit:8})));
  assert.equal(result.ok,true,result.error);return result.handle;
};
const send=(id,command)=>JSON.parse(dispatch_editor(id,JSON.stringify(command)));

test('compact responses keep full state and timeline while exporting history only on demand',()=>{
  const initial={items:Array.from({length:120},(_,id)=>({id,title:'Task '+id,meta:{tags:['work'],done:false}}))};
  const opened=JSON.parse(open_editor(JSON.stringify({initial,limit:25,include_session:false})));
  assert.equal(opened.ok,true,opened.error);
  try{
    let state=initial, result;
    for(let i=0;i<40;i++){
      state=structuredClone(state);state.items[i].meta.done=true;
      result=send(opened.handle,{op:'record',value:state,label:'Complete task'});
      assert.equal(result.ok,true);assert.equal('session' in result,false);
    }
    assert.deepEqual(result.state,state);assert.equal(result.timeline.length,26);
    const exported=send(opened.handle,{op:'export'});
    assert.equal(exported.session.revisions.length,26);
    const restored=JSON.parse(open_editor(JSON.stringify({session:exported.session,include_session:false})));
    assert.equal(restored.ok,true,restored.error);
    try{
      assert.deepEqual(send(restored.handle,{op:'status'}),result);
      assert.equal(send(restored.handle,{op:'undo'}).state.items[39].meta.done,false);
    }finally{close_editor(restored.handle);}
    assert.ok(JSON.stringify(result).length*10<JSON.stringify(exported).length);
  }finally{close_editor(opened.handle);}
});

test('prepare_save validates the final savepoint width at the exact request-size boundary',()=>{
  const session={version:1,limit:1,cursor:0,next_id:11,saved_id:0,revisions:[{id:10,label:'Current',value:''}]};
  session.revisions[0].value='a'.repeat(2000000-JSON.stringify({session}).length);
  const request=JSON.stringify({session});assert.equal(request.length,2000000);
  const opened=JSON.parse(open_editor(request));assert.equal(opened.ok,true,opened.error);
  try{
    assert.equal(send(opened.handle,{op:'export'}).ok,true);
    assert.match(send(opened.handle,{op:'prepare_save'}).error,/exceeds/);
    assert.equal(send(opened.handle,{op:'status'}).dirty,true);
  }finally{close_editor(opened.handle);}
});

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
