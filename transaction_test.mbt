///|
test "outer transaction commits multiple previews as one undo step" {
  let h = int_history()
  assert_eq(h.begin("Edit settings"), Ok(()))
  ignore(h.record(1, "preview 1"))
  ignore(h.record(2, "preview 2"))
  assert_eq(h.state(), 2)
  assert_eq(h.timeline().length(), 1)
  assert_true(!h.can_undo() && !h.can_redo())
  assert_eq(h.commit(), Ok(true))
  assert_eq(h.undo_depth(), 1)
  assert_eq(h.undo_label(), Some("Edit settings"))
  ignore(h.undo())
  assert_eq(h.state(), 0)
  ignore(h.redo())
  assert_eq(h.state(), 2)
}

///|
test "rollback restores state and preserves existing redo branch" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.undo())
  ignore(h.begin("cancel me"))
  ignore(h.record(9, "preview"))
  assert_eq(h.rollback(), Ok(true))
  assert_eq(h.state(), 0)
  assert_true(h.can_redo())
  ignore(h.redo())
  assert_eq(h.state(), 1)
}

///|
test "nested rollback restores inner baseline and outer commit is atomic" {
  let h = int_history()
  ignore(h.begin("outer"))
  ignore(h.record(1, "first"))
  ignore(h.begin("inner"))
  ignore(h.record(2, "second"))
  ignore(h.rollback())
  assert_eq(h.state(), 1)
  assert_eq(h.transaction_depth(), 1)
  ignore(h.record(3, "third"))
  ignore(h.commit())
  assert_eq(h.undo_depth(), 1)
  ignore(h.undo())
  assert_eq(h.state(), 0)
}

///|
test "nested commit folds into outer and outer rollback cancels all" {
  let h = int_history()
  ignore(h.begin("outer"))
  ignore(h.record(1, "first"))
  ignore(h.begin("inner"))
  ignore(h.record(2, "second"))
  assert_eq(h.commit(), Ok(true))
  assert_eq(h.state(), 2)
  assert_eq(h.revision_id(), 0)
  ignore(h.rollback())
  assert_eq(h.state(), 0)
  assert_eq(h.timeline().length(), 1)
}

///|
test "net-zero transaction does not erase redo or consume a revision" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.undo())
  ignore(h.begin("zero"))
  ignore(h.record(9, "temporary"))
  ignore(h.record(0, "restore"))
  assert_eq(h.commit(), Ok(false))
  assert_true(h.can_redo())
  ignore(h.redo())
  assert_eq(h.state(), 1)
}

///|
test "navigation resize and clear are rejected atomically during previews" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.begin("locked"))
  ignore(h.record(2, "preview"))
  assert_true(h.undo() is Err(_))
  assert_true(h.redo() is Err(_))
  assert_true(h.jump_to(0) is Err(_))
  assert_true(h.set_capacity(1) is Err(_))
  assert_true(h.clear() is Err(_))
  assert_eq(h.state(), 2)
  assert_eq(h.transaction_depth(), 1)
  assert_eq(h.capacity(), 100)
  ignore(h.rollback())
  assert_eq(h.state(), 1)
}

///|
test "empty and unmatched transactions are explicit" {
  let h = int_history()
  assert_true(h.commit() is Err(_))
  assert_true(h.rollback() is Err(_))
  ignore(h.begin("empty"))
  assert_eq(h.commit(), Ok(false))
  assert_eq(h.undo_depth(), 0)
}

///|
test "nesting limit does not corrupt active frames" {
  let h = int_history()
  for _ in 0..<64 {
    assert_eq(h.begin("nested"), Ok(()))
  }
  assert_true(h.begin("overflow") is Err(_))
  assert_eq(h.transaction_depth(), 64)
  for _ in 0..<64 {
    assert_eq(h.rollback(), Ok(false))
  }
  assert_eq(h.transaction_depth(), 0)
}
