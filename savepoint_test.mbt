///|
test "undo and redo across savepoint track cleanliness" {
  let h = int_history()
  assert_true(!h.is_dirty())
  ignore(h.record(1, "edit"))
  assert_true(h.is_dirty())
  ignore(h.mark_saved())
  assert_true(!h.is_dirty())
  ignore(h.undo())
  assert_true(h.is_dirty())
  ignore(h.redo())
  assert_true(!h.is_dirty())
}

///|
test "discarding saved branch cannot falsely mark equal value as saved" {
  let h = int_history()
  ignore(h.record(1, "old branch"))
  ignore(h.mark_saved())
  ignore(h.undo())
  ignore(h.record(1, "new branch same content"))
  assert_true(h.is_dirty())
  assert_eq(h.saved_revision_id(), Some(1))
  assert_eq(h.revision_id(), 2)
}

///|
test "saved checkpoint can be pruned without losing dirty status" {
  let h = int_history(limit=1)
  ignore(h.record(1, "one"))
  ignore(h.record(2, "two"))
  ignore(h.undo())
  assert_eq(h.state(), 1)
  assert_eq(h.saved_revision_id(), Some(0))
  assert_true(h.is_dirty())
}

///|
test "transaction previews are dirty and cannot claim successful saving" {
  let h = int_history()
  ignore(h.begin("preview"))
  assert_true(!h.is_dirty())
  ignore(h.record(1, "edit"))
  assert_true(h.is_dirty())
  assert_true(h.mark_saved() is Err(_))
  assert_true(h.reset(9) is Err(_))
  assert_eq(h.state(), 1)
  ignore(h.rollback())
  assert_true(!h.is_dirty())
}

///|
test "clear does not silently mark unsaved edits clean" {
  let h = int_history()
  ignore(h.record(1, "unsaved"))
  ignore(h.clear())
  assert_true(h.is_dirty())
  ignore(h.mark_saved())
  ignore(h.clear())
  assert_true(!h.is_dirty())
}

///|
test "untitled document remains dirty until explicitly saved" {
  let h = int_history()
  h.forget_saved()
  assert_true(h.is_dirty())
  assert_eq(h.saved_revision_id(), None)
  ignore(h.record(1, "one"))
  ignore(h.undo())
  assert_true(h.is_dirty())
  ignore(h.mark_saved())
  assert_true(!h.is_dirty())
}

///|
test "reset adopts isolated baseline and fresh id" {
  let h = int_history()
  ignore(h.record(1, "one"))
  ignore(h.reset(7, label="Opened file"))
  assert_eq(h.state(), 7)
  assert_eq(h.revision_id(), 2)
  assert_eq(h.timeline()[0].label, "Opened file")
  assert_true(!h.can_undo() && !h.can_redo() && !h.is_dirty())
}
