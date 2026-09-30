// Realistic adapter workloads. Wall-clock timings are reports, never CI pass/fail thresholds.
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {platform,arch,cpus} from 'node:os';
import {readFileSync,writeFileSync} from 'node:fs';
import {open_editor,dispatch_editor,close_editor} from '../web/moonundo.mjs';
const build=JSON.parse(readFileSync(new URL('../web/build-info.json',import.meta.url),'utf8'));
const bytes=value=>Buffer.byteLength(JSON.stringify(value));
const checked=text=>{const result=JSON.parse(text);assert.equal(result.ok,true,result.error);return result;};
const send=(handle,command)=>checked(dispatch_editor(handle,JSON.stringify(command)));
const median=values=>[...values].sort((a,b)=>a-b)[Math.floor(values.length/2)];
const percentile=(values,p)=>[...values].sort((a,b)=>a-b)[Math.ceil(values.length*p)-1];
const tasks=count=>({items:Array.from({length:count},(_,id)=>({id,title:`Task ${id}: review the release`,done:false,meta:{tags:['work','moonbit']}}))});
const document={title:'Project handbook',sections:Array.from({length:20},(_,i)=>({heading:`Section ${i}`,lines:Array.from({length:8},(_,j)=>`Paragraph ${j}: `+'Document details. '.repeat(3))}))};
const workloads=[
  {name:'100 tasks / 10 history steps',initial:tasks(100),capacity:10,kind:'tasks'},
  {name:'100 tasks / 50 history steps',initial:tasks(100),capacity:50,kind:'tasks'},
  {name:'500 tasks / 10 history steps',initial:tasks(500),capacity:10,kind:'tasks'},
  {name:'500 tasks / 25 history steps',initial:tasks(500),capacity:25,kind:'tasks'},
  {name:'Nested document / 50 history steps',initial:document,capacity:50,kind:'document'},
];
function run(workload,commands,includeSession){
  const {handle}=checked(open_editor(JSON.stringify({initial:workload.initial,limit:workload.capacity,include_session:includeSession})));
  const samples=[];let totalResponseBytes=0,result,lastResponseBytes;
  try{
    for(const command of commands){
      const start=performance.now();
      const response=dispatch_editor(handle,command);
      result=checked(response);
      samples.push(performance.now()-start);
      lastResponseBytes=Buffer.byteLength(response);totalResponseBytes+=lastResponseBytes;
    }
    const exportStart=performance.now(), session=send(handle,{op:'export'}).session, exportMs=performance.now()-exportStart;
    const restoreStart=performance.now();
    const restored=checked(open_editor(JSON.stringify({session,include_session:includeSession})));
    const restoreMs=performance.now()-restoreStart;
    try{
      assert.deepEqual(send(restored.handle,{op:'status'}),result);
      const previous=send(restored.handle,{op:'undo'});
      assert.equal(previous.undo_depth,workload.capacity-1);
      assert.deepEqual(send(restored.handle,{op:'redo'}),result);
    }finally{close_editor(restored.handle);}
    const {session:unused,...status}=result;
    return {status,session,totalMs:samples.reduce((a,b)=>a+b,0),p95EditMs:percentile(samples,.95),lastResponseBytes,totalResponseBytes,exportMs,restoreMs};
  }finally{close_editor(handle);}
}
const results=[];
for(const workload of workloads){
  let state=structuredClone(workload.initial);
  const commands=Array.from({length:80},(_,i)=>{
    state=structuredClone(state);
    if(workload.kind==='tasks')state.items[i%state.items.length].done=!state.items[i%state.items.length].done;
    else state.sections[i%state.sections.length].lines[0]=`Revision ${i}: edited paragraph`;
    return JSON.stringify({op:'record',value:state,label:`Edit ${i}`});
  });
  const trials={full:[],compact:[]};
  // Warm both code paths; alternate their measurement order to reduce ordering bias.
  run(workload,commands,true);run(workload,commands,false);
  let sample;
  for(let trial=0;trial<3;trial++){
    const pair={};
    for(const mode of trial%2?['compact','full']:['full','compact'])pair[mode]=run(workload,commands,mode==='full');
    assert.deepEqual(pair.full.status,pair.compact.status);
    assert.deepEqual(pair.full.session,pair.compact.session);
    for(const mode of ['full','compact']){
      const {status,session,...measurements}=pair[mode];trials[mode].push(measurements);
    }
    sample=pair.compact;
  }
  const summaries=Object.fromEntries(['full','compact'].map(mode=>[mode,Object.fromEntries(Object.keys(trials[mode][0]).map(key=>[key,median(trials[mode].map(t=>t[key]))]))]));
  results.push({name:workload.name,operations:commands.length,capacity:workload.capacity,currentStateBytes:bytes(sample.status.state),
    retainedSnapshots:sample.session.revisions.length,snapshotValueBytes:sample.session.revisions.reduce((sum,r)=>sum+bytes(r.value),0),
    archiveUtf16Units:JSON.stringify({session:sample.session,include_session:false}).length,identicalArchives:true,trials,median:summaries});
}
const report={measuredAt:new Date().toISOString(),node:process.version,platform:platform(),arch:arch(),cpu:cpus()[0]?.model,
  toolchain:build.toolchain,engineSha256:build.engineSha256,results,
  notes:['80 distinct ungrouped edits per workload; both modes use the same incremental MoonBit engine.',
    'Edit time includes dispatch and JSON.parse; inputs are prepared in advance. Reported median aggregates three warmed trials.',
    'p95EditMs is the median of each trial\'s 95th-percentile edit latency. Exports and restores are measured separately.',
    'snapshotValueBytes measures logical JSON payload, not process heap or a memory limit. Generic history also retains a live copy and transaction previews.',
    'No universal speed or maximum-document-size claim. Copying current state and timeline remains necessary in compact mode.']};
const outputIndex=process.argv.indexOf('--output');
if(outputIndex!==-1){assert.ok(process.argv[outputIndex+1],'--output needs a filename');writeFileSync(process.argv[outputIndex+1],JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify(report,null,2));
