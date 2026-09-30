///|
fn editor_result(
  editor : @moonundo.JsonEditor,
  command : Json,
) -> Map[String, Json] raise {
  let result = @json.parse(editor.dispatch(command.stringify()))
  guard result is Object(fields) else { fail("expected object") }
  return fields
}

///|
test "incremental editor survives long transactions and keeps one undo step" {
  let editor = @moonundo.JsonEditor::new("{\"initial\":0}").unwrap()
  ignore(editor_result(editor, { "op": "begin", "label": "long edit" }))
  for i in 1..<2501 {
    assert_eq(
      editor_result(editor, { "op": "record", "value": i })["ok"],
      true.to_json(),
    )
  }
  let committed = editor_result(editor, { "op": "commit" })
  assert_eq(committed["state"], (2500).to_json())
  assert_eq(committed["undo_depth"], (1).to_json())
  assert_eq(editor_result(editor, { "op": "undo" })["state"], (0).to_json())
}

///|
test "prepare save does not mutate live dirty flag or close an edit group" {
  let editor = @moonundo.JsonEditor::new("{\"initial\":0}").unwrap()
  ignore(
    editor_result(editor, { "op": "record", "value": 1, "group": "typing" }),
  )
  let before = editor.status()
  let prepared = editor_result(editor, { "op": "prepare_save" })
  assert_eq(editor.status(), before)
  let request : Json = { "session": prepared["session"] }
  let restored = @moonundo.JsonEditor::new(request.stringify()).unwrap()
  assert_eq(
    editor_result(restored, { "op": "status" })["dirty"],
    false.to_json(),
  )
  let merged = editor_result(editor, {
    "op": "record",
    "value": 2,
    "group": "typing",
  })
  assert_eq(merged["undo_depth"], (1).to_json())
}

///|
test "bad incremental commands are atomic even during transactions" {
  let editor = @moonundo.JsonEditor::new("{\"initial\":[1,2]}").unwrap()
  ignore(editor_result(editor, { "op": "begin", "label": "x" }))
  ignore(editor_result(editor, { "op": "record", "value": [3, 4] }))
  let before = editor.status()
  for
    command in [
      "{bad", "{\"op\":\"record\",\"value\":9,\"group\":false}", "{\"op\":\"undo\"}",
      "{\"op\":\"prepare_save\"}", "{\"op\":\"capacity\",\"limit\":0}",
    ] {
    let output = @json.parse(editor.dispatch(command))
    guard output is Object(fields) else { fail("expected object") }
    assert_eq(fields["ok"], false.to_json())
    assert_eq(editor.status(), before)
  }
  assert_eq(
    editor_result(editor, { "op": "rollback" })["state"],
    [1, 2].to_json(),
  )
}

///|
test "constructing editors rejects replay scripts and isolates instances" {
  assert_true(
    @moonundo.JsonEditor::new("{\"initial\":0,\"commands\":[]}") is Err(_),
  )
  let first = @moonundo.JsonEditor::new("{\"initial\":0}").unwrap()
  let second = @moonundo.JsonEditor::new("{\"initial\":0}").unwrap()
  ignore(editor_result(first, { "op": "record", "value": 7 }))
  assert_eq(editor_result(second, { "op": "status" })["state"], (0).to_json())
}
