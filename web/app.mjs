import {reduce} from './moonundo.mjs';
import {EditorModel} from './editor-model.mjs';
const $ = id => document.getElementById(id);
const presets = {
  settings: {name:'我的创作空间', theme:'light', notifications:true},
  tasks: {items:[{id:1,title:'尝试完成一项任务，再撤销',done:false},{id:2,title:'误删也能从时间线找回来',done:false}],next_id:3},
  canvas: {shapes:[{id:1,x:62,y:76,color:'violet'},{id:2,x:234,y:155,color:'mint'}],next_id:3}
};
const models = Object.fromEntries(Object.entries(presets).map(([kind,initial]) => [kind,new EditorModel({initial,limit:50})]));
let kind = 'settings', selected = 1, drag = null;
function message(text, error = false) { $('message').textContent = text; $('message').classList.toggle('error',error); }
function dispatch(command, notice) {
  const model = models[kind];
  try {
    model.apply(command);
    render(); if (notice) message(notice);
    return true;
  } catch (error) { message(error.message,true); return false; }
}
function edit(action, label, group = '') {
  try {
    const next = JSON.parse(reduce(JSON.stringify({kind,state:models[kind].result.state,action})));
    if (!next.ok) throw new Error(next.error);
    return dispatch({op:'record',value:next.state,label,group});
  } catch(error) { message(error.message,true); return false; }
}
function button(text, action, className) {
  const node = document.createElement('button'); node.textContent = text;
  if (className) node.className = className;
  node.addEventListener('click',action); return node;
}
function render() {
  const r = models[kind].result, active = r.transaction_depth > 0;
  document.querySelectorAll('[data-tab]').forEach(b => { b.classList.toggle('active',b.dataset.tab===kind); b.setAttribute('aria-pressed',b.dataset.tab===kind); });
  for (const k of Object.keys(presets)) $(k+'-panel').hidden = k !== kind;
  $('undo').disabled = !r.can_undo; $('redo').disabled = !r.can_redo;
  $('undo').title = r.undo_label ? `撤销：${r.undo_label}` : '没有可撤销的操作';
  $('redo').title = r.redo_label ? `重做：${r.redo_label}` : '没有可重做的操作';
  $('dirty').textContent = active ? '批量修改中' : r.dirty ? '有未保存的修改' : '与保存点一致';
  $('dirty').classList.toggle('dirty',r.dirty || active);
  ['save','restore','export','import','capacity'].forEach(id => $(id).disabled = active);
  $('begin').hidden = active; $('commit').hidden = !active; $('rollback').hidden = !active;
  $('depths').textContent = `${r.undo_depth} / ${r.redo_depth}`;
  $('transaction').textContent = r.transaction_depth;
  $('revision-count').textContent = `${r.timeline.length} 个状态`;
  if (![...$('capacity').options].some(option => Number(option.value) === r.capacity)) {
    const option = document.createElement('option'); option.value = r.capacity; option.textContent = `${r.capacity} 步`; $('capacity').append(option);
  }
  $('capacity').value = r.capacity;
  $('timeline').replaceChildren(...r.timeline.map((entry,i) => {
    const li = document.createElement('li');
    const b = button(entry.label === 'Initial' ? '初始状态' : entry.label, () => dispatch({op:'jump',index:i},'已切换到选中的历史状态。'),entry.current?'current':i>r.undo_depth?'future':'');
    const number = document.createElement('small'); number.textContent = `#${entry.revision_id}`; b.append(number); b.disabled = active;
    if(entry.current)b.setAttribute('aria-current','step'); li.append(b);return li;
  }));
  if(kind==='settings') {
    const s = r.state;
    if($('name').value!==s.name)$('name').value=s.name;
    $('theme').value=s.theme;$('notifications').checked=s.notifications;
    $('preview-name').textContent=s.name || '未命名空间';
    $('preview-description').textContent=`${s.theme==='dark'?'深色':'明亮'}主题 · 任务提醒${s.notifications?'开启':'关闭'}`;
    $('settings-preview').classList.toggle('dark',s.theme==='dark');
  } else if(kind==='tasks') {
    $('task-list').replaceChildren(...r.state.items.map(task=>{
      const li=document.createElement('li');li.classList.toggle('done',task.done);
      const check=document.createElement('input');check.type='checkbox';check.checked=task.done;check.setAttribute('aria-label',`完成 ${task.title}`);
      check.onchange=()=>edit({type:'toggle',id:task.id},task.done?'取消完成任务':'完成任务');
      const title=document.createElement('span');title.textContent=task.title;
      const remove=button('删除',()=>edit({type:'remove',id:task.id},'删除任务'));remove.setAttribute('aria-label',`删除 ${task.title}`);
      li.append(check,title,remove);return li;
    }));
    if(!r.state.items.length){const li=document.createElement('li');li.className='empty';li.textContent='清单空了。添加新任务，或撤销找回。';$('task-list').append(li);}
    $('complete-all').disabled=!r.state.items.some(t=>!t.done);
    $('remove-completed').disabled=!r.state.items.some(t=>t.done);
  } else {
    if(!r.state.shapes.some(s=>s.id===selected))selected=r.state.shapes[0]?.id ?? null;
    $('shapes').replaceChildren(...r.state.shapes.map(shape=>{
      const node=document.createElement('div');node.className=`shape ${shape.color}${shape.id===selected?' selected':''}`;
      node.dataset.id=shape.id;node.style.left=`${shape.x/5}%`;node.style.top=`${shape.y/3.4}%`;node.textContent=`${shape.id}`;
      node.setAttribute('aria-label',`图形 ${shape.id}`);return node;
    }));
    $('color-shape').disabled=selected===null;$('remove-shape').disabled=selected===null;
  }
}
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{
  if(models[kind].result.transaction_depth){message('请先提交或取消当前批量修改。',true);return;}
  kind=b.dataset.tab;render();message('三个示例各自拥有独立历史。');
});
$('undo').onclick=()=>dispatch({op:'undo'},'已撤销。');$('redo').onclick=()=>dispatch({op:'redo'},'已重做。');
$('name').oninput=()=>edit({type:'name',value:$('name').value},'修改工作区名称','name');
$('name').onblur=()=>dispatch({op:'break_group'});
$('theme').onchange=()=>edit({type:'theme',value:$('theme').value},'切换主题');
$('notifications').onchange=()=>edit({type:'notifications',value:$('notifications').checked},'更改提醒设置');
$('begin').onclick=()=>dispatch({op:'begin',label:'批量修改设置'},'预览修改中：提交会合为一步，取消会全部恢复。');
$('commit').onclick=()=>dispatch({op:'commit'},'整组修改已提交，可一次撤销。');
$('rollback').onclick=()=>dispatch({op:'rollback'},'整组修改已取消，原有历史保留。');
$('task-form').onsubmit=e=>{e.preventDefault();if(edit({type:'add',title:$('task-title').value},'添加任务'))$('task-title').value='';};
$('complete-all').onclick=()=>edit({type:'complete_all'},'全部完成');
$('remove-completed').onclick=()=>edit({type:'remove_completed'},'清理已完成任务');
$('add-shape').onclick=()=>{if(edit({type:'add'},'添加图形')){selected=models.canvas.result.state.shapes.at(-1).id;render();}};
$('color-shape').onclick=()=>{const s=models.canvas.result.state.shapes.find(s=>s.id===selected);if(s)edit({type:'color',id:selected,color:{violet:'mint',mint:'amber',amber:'violet'}[s.color]},'切换图形颜色');};
$('remove-shape').onclick=()=>{if(selected!==null)edit({type:'remove',id:selected},'删除图形');};
$('stage').onpointerdown=e=>{
  const node=e.target.closest('[data-id]');if(!node)return;
  selected=Number(node.dataset.id);const s=models.canvas.result.state.shapes.find(s=>s.id===selected);
  drag={id:selected,x:s.x,y:s.y,px:e.clientX,py:e.clientY};$('stage').setPointerCapture(e.pointerId);$('stage').focus();render();e.preventDefault();
};
$('stage').onpointermove=e=>{
  if(!drag)return;const rect=$('stage').getBoundingClientRect();
  edit({type:'move',id:drag.id,x:Math.max(0,Math.round(drag.x+(e.clientX-drag.px)*500/rect.width)),y:Math.max(0,Math.round(drag.y+(e.clientY-drag.py)*340/rect.height))},'移动图形',`drag-${drag.id}`);
};
for(const event of ['pointerup','pointercancel','lostpointercapture'])$('stage').addEventListener(event,()=>{if(drag){drag=null;dispatch({op:'break_group'},'拖动已结束，连续移动合并为一步。');}});
$('stage').onkeydown=e=>{
  const s=models.canvas.result.state.shapes.find(s=>s.id===selected);if(!s)return;
  const vectors={ArrowLeft:[-5,0],ArrowRight:[5,0],ArrowUp:[0,-5],ArrowDown:[0,5]};
  if(vectors[e.key]){e.preventDefault();const [x,y]=vectors[e.key];edit({type:'move',id:selected,x:Math.max(0,s.x+x),y:Math.max(0,s.y+y)},'键盘移动图形',`key-${selected}`);}
  if(e.key==='Delete'){e.preventDefault();$('remove-shape').click();}
};
$('stage').onkeyup=()=>dispatch({op:'break_group'});
$('capacity').onchange=()=>dispatch({op:'capacity',limit:Number($('capacity').value)},'容量已更新：保留当前状态和最近的历史。');
function envelope(session){return {format:'moonundo-demo',version:1,kind,session};}
function loadEnvelope(data){
  const candidate=EditorModel.fromEnvelope(data,kind);
  models[kind].close();
  models[kind]=candidate;render();
}
$('save').onclick=()=>{
  try{
    models[kind].save(session=>localStorage.setItem('moonundo:'+kind,JSON.stringify(envelope(session))));
    render();message('已保存到当前浏览器。关闭页面后，可用“恢复本机存档”找回。');
  }catch(error){message('保存失败，未更新保存点：'+error.message,true);}
};
$('restore').onclick=()=>{try{const text=localStorage.getItem('moonundo:'+kind);if(!text)throw new Error('当前示例还没有本机存档。');loadEnvelope(JSON.parse(text));message('已恢复本机存档，撤销和重做仍然可用。');}catch(error){message(error.message,true);}};
$('export').onclick=()=>{
  const url=URL.createObjectURL(new Blob([JSON.stringify(envelope(models[kind].result.session),null,2)],{type:'application/json'}));
  const a=document.createElement('a');a.href=url;a.download=`moonundo-${kind}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);message('历史文件已交给浏览器下载；保存点未改变。');
};
$('import').onchange=async()=>{
  const originalKind=kind, model=models[kind], epoch=model.epoch;
  try{
    const file=$('import').files[0];if(!file)return;
    if(file.size>2000000)throw new Error('文件需小于 2 MB。');
    const data=JSON.parse(await file.text());
    if(kind!==originalKind || models[kind]!==model || model.epoch!==epoch)throw new Error('读取文件期间发生了编辑或切换，请重新导入。');
    loadEnvelope(data);message('历史已导入。');
  }catch(error){message('导入失败，原状态保留：'+error.message,true);}finally{$('import').value='';}
};
document.addEventListener('keydown',e=>{
  if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='z'&&!['INPUT','TEXTAREA'].includes(document.activeElement.tagName)){
    e.preventDefault();$(e.shiftKey?'redo':'undo').click();
  }
});
render();message('可以开始体验。点击“保存到本机”保存当前示例和完整历史。');
