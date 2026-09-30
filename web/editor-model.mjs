import {open_editor, dispatch_editor, close_editor, reduce} from './moonundo.mjs';

function checked(text) {
  const result = JSON.parse(text);
  if (!result.ok) throw new Error(result.error);
  return result;
}

// UI owns a handle and display state; all history transitions run in MoonBit.
export class EditorModel {
  constructor(request) {
    this.handle = checked(open_editor(JSON.stringify({...request,include_session:false}))).handle;
    this.epoch = 0;
    this.result = checked(dispatch_editor(this.handle, '{"op":"status"}'));
  }
  apply(command) {
    const result = checked(dispatch_editor(this.handle, JSON.stringify(command)));
    this.result = result;
    this.epoch++;
    return result;
  }
  save(writeSynchronously) {
    const prepared = checked(dispatch_editor(this.handle, '{"op":"prepare_save"}'));
    writeSynchronously(prepared.session); // A storage exception leaves history untouched.
    return this.apply({op:'save'});
  }
  exportSession() {
    return checked(dispatch_editor(this.handle, '{"op":"export"}')).session;
  }
  close() {
    if (this.handle !== null) close_editor(this.handle);
    this.handle = null;
    this.epoch++;
  }
  static fromEnvelope(data, kind) {
    if (!data || data.format !== 'moonundo-demo' || data.version !== 1 || data.kind !== kind) {
      throw new Error('请选择当前示例的 MoonUndo 历史文件。');
    }
    const candidate = new EditorModel({session:data.session});
    try {
      for (const revision of data.session.revisions) {
        checked(reduce(JSON.stringify({kind,state:revision.value,action:{type:'validate'}})));
      }
      return candidate;
    } catch (error) { candidate.close(); throw new Error('历史中的应用数据无效：' + error.message); }
  }
}
