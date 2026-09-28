///|
fn decode_int(j : Json) -> Result[Int, String] {
  Ok(@json.from_json(j)) catch {
    _ => Err("expected integer")
  }
}

///|
fn roundtrip(h : @moonundo.History[Int]) -> @moonundo.History[Int] {
  @moonundo.restore_session(
    h.export_session(fn(x) { x.to_json() }).unwrap(),
    decode_int,
    copy=fn(x) { x },
    equal=fn(a, b) { a == b },
  ).unwrap()
}

///|
test "session preserves redo savepoint labels and next identifier" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.mark_saved())
  ignore(h.record(2, "two"))
  ignore(h.undo())
  let restored = roundtrip(h)
  assert_eq(restored.state(), 1)
  assert_true(!restored.is_dirty())
  assert_eq(restored.redo_label(), Some("two"))
  ignore(restored.redo())
  assert_eq(restored.state(), 2)
  ignore(restored.record(3, "three"))
  assert_eq(restored.revision_id(), 3)
}

///|
test "pruned saved revision and forgotten savepoint survive session" {
  let h = int_history(limit=1)
  ignore(h.record(1, "one"))
  ignore(h.record(2, "two"))
  assert_true(roundtrip(h).is_dirty())
  assert_eq(roundtrip(h).saved_revision_id(), Some(0))
  h.forget_saved()
  assert_eq(roundtrip(h).saved_revision_id(), None)
}

///|
test "export rejects preview and restore breaks grouping" {
  let h = int_history()
  ignore(h.begin("preview"))
  assert_true(h.export_session(fn(x) { x.to_json() }) is Err(_))
  ignore(h.rollback())
  ignore(h.record(1, "a", group="typing"))
  let restored = roundtrip(h)
  ignore(restored.record(2, "b", group="typing"))
  assert_eq(restored.undo_depth(), 2)
}

///|
test "restore rejects malformed sessions without panics" {
  let invalid = [
    "{}", "{\"version\":2,\"limit\":1,\"cursor\":0,\"next_id\":1,\"revisions\":[{\"id\":0,\"label\":\"a\",\"value\":0}]}",
    "{\"version\":1,\"limit\":0,\"cursor\":0,\"next_id\":1,\"revisions\":[]}", "{\"version\":1,\"limit\":1,\"cursor\":2,\"next_id\":1,\"revisions\":[{\"id\":0,\"label\":\"a\",\"value\":0}]}",
    "{\"version\":1,\"limit\":1,\"cursor\":0,\"next_id\":1,\"revisions\":[{\"id\":1,\"label\":\"a\",\"value\":0}]}",
    "{\"version\":1,\"limit\":1,\"cursor\":0,\"next_id\":1,\"saved_id\":2,\"revisions\":[{\"id\":0,\"label\":\"a\",\"value\":0}]}",
    "{\"version\":1,\"limit\":1,\"cursor\":0,\"next_id\":2,\"revisions\":[{\"id\":0,\"label\":\"a\",\"value\":\"bad\"}]}",
    "{\"version\":1,\"limit\":1,\"cursor\":0,\"next_id\":2,\"revisions\":[{\"id\":0,\"label\":\"a\",\"value\":0},{\"id\":0,\"label\":\"b\",\"value\":1}]}",
  ]
  for text in invalid {
    let value = @json.parse(text)
    assert_true(
      @moonundo.restore_session(value, decode_int, copy=fn(x) { x }, equal=fn(
        a,
        b,
      ) {
        a == b
      })
      is Err(_),
    )
  }
}
