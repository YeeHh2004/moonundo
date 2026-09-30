///|
let editors : Map[Int, @undo.JsonEditor] = Map([])

///|
let next_handle : Ref[Int] = Ref(1)

///|
/// At most 64 live handles. Close replaced editors; identifiers are never reused.
pub fn open_editor(text : String) -> String {
  if editors.length() >= 64 || next_handle.val == 2147483647 {
    let error : Json = { "ok": false, "error": "editor handle limit reached" }
    return error.stringify()
  }
  match @undo.JsonEditor::new(text) {
    Err(message) => {
      let error : Json = { "ok": false, "error": message }
      error.stringify()
    }
    Ok(editor) => {
      let handle = next_handle.val
      next_handle.val += 1
      editors[handle] = editor
      let response : Json = { "ok": true, "handle": handle }
      response.stringify()
    }
  }
}

///|
pub fn dispatch_editor(handle : Int, text : String) -> String {
  match editors.get(handle) {
    Some(editor) => editor.dispatch(text)
    None => {
      let error : Json = { "ok": false, "error": "unknown or closed editor" }
      error.stringify()
    }
  }
}

///|
pub fn close_editor(handle : Int) -> Bool {
  let present = editors.contains(handle)
  editors.remove(handle)
  present
}
