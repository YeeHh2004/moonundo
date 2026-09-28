///|
fn int_history(limit? : Int = 100) -> @moonundo.History[Int] {
  @moonundo.History::new(0, copy=fn(x) { x }, equal=fn(a, b) { a == b }, limit~).unwrap()
}

///|
test "initial state and empty undo redo" {
  let h = int_history()
  assert_eq(h.state(), 0)
  assert_true(!h.can_undo() && !h.can_redo())
  assert_eq(h.undo(), Ok(false))
  assert_eq(h.redo(), Ok(false))
}

///|
test "record undo redo preserve ordered states" {
  let h = int_history()
  assert_eq(h.record(1, "one"), Ok(true))
  assert_eq(h.record(2, "two"), Ok(true))
  assert_eq(h.undo(), Ok(true))
  assert_eq(h.state(), 1)
  assert_eq(h.undo(), Ok(true))
  assert_eq(h.state(), 0)
  assert_eq(h.redo(), Ok(true))
  assert_eq(h.state(), 1)
  assert_eq(h.redo(), Ok(true))
  assert_eq(h.state(), 2)
}

///|
test "genuine edit after undo discards future branch" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.record(2, "two"))
  ignore(h.undo())
  ignore(h.record(3, "branch"))
  assert_true(!h.can_redo())
  ignore(h.undo())
  assert_eq(h.state(), 1)
}

///|
test "no-op after undo preserves future" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.undo())
  assert_eq(h.record(0, "no change"), Ok(false))
  assert_true(h.can_redo())
  ignore(h.redo())
  assert_eq(h.state(), 1)
}

///|
test "bounded snapshots retain current and nearest undo states" {
  let h = int_history(limit=2)
  for i in 1..<=6 {
    ignore(h.record(i, "edit"))
  }
  ignore(h.undo())
  assert_eq(h.state(), 5)
  ignore(h.undo())
  assert_eq(h.state(), 4)
  assert_eq(h.undo(), Ok(false))
}

///|
test "limits reject zero negative and oversized allocations" {
  for limit in [-1, 0, 10001] {
    assert_true(
      @moonundo.History::new(
        0,
        copy=fn(x) { x },
        equal=fn(a, b) { a == b },
        limit~,
      )
      is Err(_),
    )
  }
}

///|
test "mutable arrays are isolated on initial record read undo and redo" {
  let initial = [1]
  let h = @moonundo.History::new(initial, copy=fn(x) { x.copy() }, equal=fn(
    a,
    b,
  ) {
    a == b
  }).unwrap()
  initial[0] = 99
  assert_eq(h.state(), [1])
  let next = [2]
  ignore(h.record(next, "edit"))
  next[0] = 99
  let output = h.state()
  output[0] = 88
  assert_eq(h.state(), [2])
  ignore(h.undo())
  h.state()[0] = 77
  assert_eq(h.state(), [1])
  ignore(h.redo())
  assert_eq(h.state(), [2])
}

///|
test "generic history supports Unicode strings without normalizing" {
  let h = @moonundo.History::new("你好 🎨", copy=fn(x) { x }, equal=fn(
    a,
    b,
  ) {
    a == b
  }).unwrap()
  ignore(h.record("é", "combining mark"))
  ignore(h.undo())
  assert_eq(h.state(), "你好 🎨")
  ignore(h.redo())
  assert_eq(h.state(), "é")
}
