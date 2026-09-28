///|
test "JSON adapter performs a transaction and emits restorable session" {
  let response = @json.parse(
    @moonundo.replay(
      "{\"initial\":{\"x\":0},\"commands\":[{\"op\":\"begin\",\"label\":\"move\"},{\"op\":\"record\",\"value\":{\"x\":10}},{\"op\":\"record\",\"value\":{\"x\":20}},{\"op\":\"commit\"},{\"op\":\"undo\"}]}",
    ),
  )
  guard response is Object(fields) else { fail("expected object") }
  assert_eq(fields["ok"], true.to_json())
  assert_eq(fields["redo_depth"], (1).to_json())
  assert_eq(fields["state"], { "x": 0 })
  let restored : Json = {
    "session": fields["session"],
    "commands": [{ "op": "redo" }],
  }
  let result = @json.parse(@moonundo.replay(restored.stringify()))
  guard result is Object(output) else { fail("expected object") }
  assert_eq(output["state"], { "x": 20 })
}

///|
test "JSON adapter reports invalid requests and disallowed preview navigation" {
  for
    input in [
      "invalid", "{}", "{\"initial\":0,\"commands\":[{\"op\":\"unknown\"}]}", "{\"initial\":0,\"commands\":[{\"op\":\"begin\",\"label\":\"x\"},{\"op\":\"undo\"}]}",
      "{\"initial\":0,\"commands\":[{\"op\":\"jump\",\"index\":0.5}]}",
    ] {
    let response = @json.parse(@moonundo.replay(input))
    guard response is Object(fields) else { fail("expected object") }
    assert_eq(fields["ok"], false.to_json())
    assert_true(fields.contains("error"))
  }
}
