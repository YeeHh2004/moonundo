///|
fn exhausted_history() -> @moonundo.History[Int] {
  let session : Json = {
    "version": 1,
    "limit": 2,
    "cursor": 0,
    "next_id": 2147483647,
    "saved_id": 0,
    "revisions": [{ "id": 0, "label": "Initial", "value": 0 }],
  }
  @moonundo.restore_session(session, decode_int, copy=fn(x) { x }, equal=fn(
    a,
    b,
  ) {
    a == b
  }).unwrap()
}

///|
test "revision exhaustion rejects record reset and outer commit without corrupting state" {
  let h = exhausted_history()
  assert_true(h.record(1, "Overflow") is Err(_))
  assert_true(h.reset(2) is Err(_))
  assert_eq(h.state(), 0)
  assert_eq(h.revision_id(), 0)
  assert_true(!h.is_dirty())
  h.begin("Preview at limit").unwrap()
  ignore(h.record(3, "Preview").unwrap())
  assert_true(h.commit() is Err(_))
  assert_eq(h.transaction_depth(), 1)
  assert_eq(h.state(), 3)
  assert_true(h.rollback().unwrap())
  assert_eq(h.state(), 0)
  h.begin("No change").unwrap()
  assert_eq(h.commit(), Ok(false))
  assert_true(!h.is_dirty())
}

///|
test "replay resource limits and invalid command shapes reject on both backends" {
  let commands : Array[Json] = Array::make(2001, { "op": "undo" })
  let oversized : Json = { "initial": 0, "commands": commands }
  let mut deep : Json = (0).to_json()
  for _ in 0..<70 {
    deep = Json::array([deep])
  }
  let nested : Json = { "initial": deep, "commands": [] }
  let inputs = [
    "null",
    "{\"initial\":0,\"commands\":false}",
    "{\"initial\":0,\"commands\":[{\"op\":17}]}",
    "{\"initial\":9007199254740992,\"commands\":[]}",
    oversized.stringify(),
    nested.stringify(),
    String::make(2000001, ' '),
  ]
  for input in inputs {
    let response = @json.parse(@moonundo.replay(input))
    guard response is Object(fields) else { fail("expected rejection object") }
    assert_eq(fields["ok"], false.to_json())
    assert_true(fields.contains("error"))
    assert_true(!fields.contains("session"))
  }
}

///|
test "less common JSON commands preserve savepoints and grouping boundaries" {
  let editor = @moonundo.JsonEditor::new("{\"initial\":0}").unwrap()
  ignore(editor_result(editor, { "op": "record", "value": 1, "group": "x" }))
  ignore(editor_result(editor, { "op": "break_group" }))
  assert_eq(
    editor_result(editor, { "op": "record", "value": 2, "group": "x" })["undo_depth"],
    (2).to_json(),
  )
  ignore(editor_result(editor, { "op": "save" }))
  assert_eq(
    editor_result(editor, { "op": "forget_saved" })["dirty"],
    true.to_json(),
  )
  assert_eq(
    editor_result(editor, { "op": "clear" })["undo_depth"],
    (0).to_json(),
  )
  let reset = editor_result(editor, { "op": "reset", "value": 9 })
  assert_eq(reset["state"], (9).to_json())
  assert_eq(reset["dirty"], false.to_json())
  assert_eq(reset["undo_depth"], (0).to_json())
}

///|
test "malformed session metadata never invokes application decoders" {
  let mutations : Array[(String, Json)] = [
    ("next_id", 0),
    ("next_id", 2147483648.0),
    ("saved_id", "zero"),
    ("saved_id", 0.5),
    ("revisions", false),
    ("revisions", [null]),
    ("revisions", [{ "id": "zero", "label": "bad", "value": 0 }]),
    ("revisions", [{ "id": 0.5, "label": "bad", "value": 0 }]),
  ]
  for (key, value) in mutations {
    let valid = int_history().export_session(fn(x) { x.to_json() }).unwrap()
    guard valid is Object(fields) else { fail("expected session") }
    fields[key] = value
    let calls = Ref(0)
    let restored = @moonundo.restore_session(
      valid,
      fn(json) {
        calls.val += 1
        decode_int(json)
      },
      copy=fn(x) { x },
      equal=fn(a, b) { a == b },
    )
    assert_true(restored is Err(_))
    assert_eq(calls.val, 0)
  }
}
