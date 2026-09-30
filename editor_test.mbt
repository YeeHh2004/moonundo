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
test "compact status omits archives but preserves metadata and explicit export" {
  let full = @moonundo.JsonEditor::new("{\"initial\":0}").unwrap()
  let compact = @moonundo.JsonEditor::new(
    "{\"initial\":0,\"include_session\":false}",
  ).unwrap()
  let commands : Array[Json] = [
    { "op": "record", "value": 1 },
    { "op": "begin", "label": "batch" },
    { "op": "record", "value": 2 },
    { "op": "commit" },
    { "op": "save" },
    { "op": "undo" },
    { "op": "redo" },
  ]
  for command in commands {
    let expected = editor_result(full, command)
    let actual = editor_result(compact, command)
    assert_true(expected.contains("session"))
    assert_true(!actual.contains("session"))
    for key, value in expected {
      if key != "session" {
        assert_eq(actual[key], value)
      }
    }
  }
  assert_eq(
    editor_result(compact, { "op": "export" })["session"],
    editor_result(full, { "op": "export" })["session"],
  )
  assert_true(
    @moonundo.JsonEditor::new("{\"initial\":0,\"include_session\":\"false\"}")
    is Err(_),
  )
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
