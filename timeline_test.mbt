///|
test "timeline labels ids and cursor follow history navigation" {
  let h = int_history()
  ignore(h.record(1, "first"))
  ignore(h.record(2, "second"))
  assert_eq(h.undo_label(), Some("second"))
  assert_eq(h.redo_label(), None)
  assert_eq(h.jump_to(0), Ok(true))
  assert_eq(h.state(), 0)
  assert_eq(h.redo_label(), Some("first"))
  assert_eq(h.undo_depth(), 0)
  assert_eq(h.redo_depth(), 2)
  let entries = h.timeline()
  assert_eq(entries.map(fn(x) { x.revision_id }), [0, 1, 2])
  assert_eq(entries.map(fn(x) { x.current }), [true, false, false])
}

///|
test "out of range jump does not move or mutate state" {
  let h = int_history()
  ignore(h.record(1, "one"))
  assert_true(h.jump_to(-1) is Err(_))
  assert_true(h.jump_to(2) is Err(_))
  assert_eq(h.state(), 1)
  assert_eq(h.jump_to(1), Ok(false))
}

///|
test "stable revision ids are not reused when branching" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.record(2, "two"))
  ignore(h.undo())
  ignore(h.record(3, "branch"))
  assert_eq(h.timeline().map(fn(x) { x.revision_id }), [0, 1, 3])
}

///|
test "shrink limit at beginning preserves available future" {
  let h = int_history()
  for i in 1..<=5 {
    ignore(h.record(i, "edit"))
  }
  ignore(h.jump_to(0))
  assert_eq(h.set_capacity(2), Ok(()))
  assert_eq(h.timeline().length(), 3)
  assert_eq(h.redo_depth(), 2)
  assert_eq(h.state(), 0)
  ignore(h.redo())
  assert_eq(h.state(), 1)
}

///|
test "shrink in middle favors nearest past and retains current" {
  let h = int_history()
  for i in 1..<=6 {
    ignore(h.record(i, "edit"))
  }
  ignore(h.jump_to(4))
  ignore(h.set_capacity(2))
  assert_eq(h.state(), 4)
  assert_eq(h.timeline().map(fn(x) { x.revision_id }), [2, 3, 4])
  assert_eq(h.capacity(), 2)
  assert_true(h.set_capacity(0) is Err(_))
  assert_eq(h.capacity(), 2)
}

///|
test "clear retains state and stable id but forgets both directions" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.record(2, "two"))
  ignore(h.undo())
  ignore(h.clear())
  assert_eq(h.state(), 1)
  assert_eq(h.revision_id(), 1)
  assert_true(!h.can_undo() && !h.can_redo())
  ignore(h.record(3, "three"))
  assert_eq(h.revision_id(), 3)
}
