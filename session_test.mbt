///|
fn decode_int(j : Json) -> Result[Int, String] {
  Ok(@json.from_json(j)) catch {
    _ => Err("expected integer")
  }
}

///|
test "all metadata is checked before invoking a user decoder" {
  let invalid : Array[Json] = [
    {
      "version": 1,
      "limit": 2,
      "cursor": 0,
      "next_id": 2,
      "saved_id": null,
      "revisions": [
        { "id": 0, "label": "a", "value": 0 },
        { "id": 0, "label": "b", "value": 1 },
      ],
    },
    {
      "version": 1,
      "limit": 2,
      "cursor": 0,
      "next_id": 2,
      "saved_id": null,
      "revisions": [
        { "id": 0, "label": "a", "value": 0 },
        { "id": 1, "label": false, "value": 1 },
      ],
    },
    {
      "version": 1,
      "limit": 1,
      "cursor": 0,
      "next_id": 3,
      "saved_id": null,
      "revisions": [
        { "id": 0, "label": "a", "value": 0 },
        { "id": 1, "label": "b", "value": 1 },
        { "id": 2, "label": "c", "value": 2 },
      ],
    },
  ]
  for session in invalid {
    let calls = Ref(0)
    let result = @moonundo.restore_session(
      session,
      fn(json) {
        calls.val += 1
        decode_int(json)
      },
      copy=fn(x) { x },
      equal=fn(a, b) { a == b },
    )
    assert_true(result is Err(_))
    assert_eq(calls.val, 0)
  }
}

///|
test "export codec receives isolated arrays and restore clones decoded arrays" {
  let h = @moonundo.History::new([1], copy=fn(x) { x.copy() }, equal=fn(a, b) {
    a == b
  }).unwrap()
  let retained : Array[Array[Int]] = []
  let session = h
    .export_session(fn(x) {
      retained.push(x)
      x.to_json()
    })
    .unwrap()
  retained[0].push(99)
  assert_eq(h.state(), [1])
  let decoded : Array[Array[Int]] = []
  let restored = @moonundo.restore_session(
    session,
    fn(json) {
      let value : Array[Int] = @json.from_json(json) catch {
        _ => return Err("expected integers")
      }
      decoded.push(value)
      Ok(value)
    },
    copy=fn(x) { x.copy() },
    equal=fn(a, b) { a == b },
  ).unwrap()
  let before = restored.state()
  decoded[0].clear()
  assert_eq(restored.state(), before)
}

///|
test "codec failures leave the source history usable" {
  let h = int_history()
  ignore(h.record(1, "one"))
  let session = h.export_session(fn(x) { x.to_json() }).unwrap()
  let failed : Result[@moonundo.History[Int], String] = @moonundo.restore_session(
    session,
    fn(_) { Err("schema mismatch") },
    copy=fn(x) { x },
    equal=fn(a, b) { a == b },
  )
  assert_true(failed is Err(_))
  assert_eq(h.state(), 1)
  ignore(h.undo())
  assert_eq(h.state(), 0)
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
