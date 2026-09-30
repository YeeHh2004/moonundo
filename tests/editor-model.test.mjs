import test from 'node:test';
import assert from 'node:assert/strict';
import {EditorModel} from '../web/editor-model.mjs';
const initial={name:'Workspace',theme:'light',notifications:true};
const envelope=(session,kind='settings')=>({format:'moonundo-demo',version:1,kind,session});

test('failed storage leaves state, savepoint, redo and grouping untouched',()=>{
  const m=new EditorModel({initial});
  try{
    m.apply({op:'record',value:{...initial,name:'A'},group:'typing'});
    const before=structuredClone(m.result), epoch=m.epoch;
    assert.throws(()=>m.save(()=>{throw new Error('quota exceeded');}),/quota/);
    assert.deepEqual(m.result,before);assert.equal(m.epoch,epoch);
    m.apply({op:'record',value:{...initial,name:'B'},group:'typing'});
    assert.equal(m.result.undo_depth,1);
    let stored;m.save(s=>{stored=s;});
    const restored=EditorModel.fromEnvelope(envelope(stored),'settings');
    try{assert.equal(restored.result.dirty,false);assert.equal(restored.result.state.name,'B');}finally{restored.close();}
  }finally{m.close();}
});
test('all imported snapshots validate before replacing an editor, and failed imports release handles',()=>{
  const m=new EditorModel({initial});
  try{
    m.apply({op:'record',value:{...initial,name:'valid current'}});
    const session=m.exportSession();
    const invalid=structuredClone(session);invalid.revisions[0].value.theme='invalid';
    for(let i=0;i<80;i++)assert.throws(()=>EditorModel.fromEnvelope(envelope(invalid),'settings'),/应用数据无效/);
    const valid=EditorModel.fromEnvelope(envelope(session),'settings');
    try{assert.equal(valid.result.state.name,'valid current');}finally{valid.close();}
    assert.throws(()=>EditorModel.fromEnvelope(envelope(session),'tasks'),/当前示例/);
    assert.equal(m.result.state.name,'valid current');
  }finally{m.close();}
});
test('edits exceed old script-size and command limits without accumulating replay inputs',()=>{
  const m=new EditorModel({initial:{text:'a'.repeat(5000)}});
  try{
    for(let i=0;i<2200;i++)m.apply({op:'record',value:{text:'a'.repeat(5000),i},group:'long edit'});
    assert.equal(m.result.undo_depth,1);assert.equal(m.result.state.i,2199);
    m.apply({op:'undo'});assert.deepEqual(m.result.state,{text:'a'.repeat(5000)});
    assert.equal('commands' in m,false);
    assert.equal('session' in m.result,false,'UI updates do not serialize the whole archive');
  }finally{m.close();}
});

test('export does not change savepoint and rejects archives beyond adapter limits',()=>{
  const m=new EditorModel({initial:0,limit:100});
  try{
    m.apply({op:'record',value:1});
    const before=structuredClone(m.result);
    const session=m.exportSession();assert.deepEqual(m.result,before);assert.equal(session.saved_id,0);
    const text='a'.repeat(30000);
    for(let i=0;i<70;i++)m.apply({op:'record',value:{text,i}});
    assert.throws(()=>m.exportSession(),/exceeds/);
    let wrote=false;assert.throws(()=>m.save(()=>{wrote=true;}),/exceeds/);assert.equal(wrote,false);
    m.apply({op:'capacity',limit:5});
    assert.equal(m.exportSession().revisions.length,6);
  }finally{m.close();}
});
