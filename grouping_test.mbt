///|
test "same group coalesces consecutive edits into one undo step" {
  let h = int_history()
  for i in 1..<=8 {
    ignore(h.record(i, "Drag", group="node-x"))
  }
  assert_eq(h.undo_depth(), 1)
  assert_eq(h.revision_id(), 8)
  ignore(h.undo())
  assert_eq(h.state(), 0)
  ignore(h.redo())
  assert_eq(h.state(), 8)
}

///|
test "empty and different group keys separate edits" {
  let h = int_history()
  ignore(h.record(1, "x", group="x"))
  ignore(h.record(2, "y", group="y"))
  ignore(h.record(3, "plain"))
  ignore(h.record(4, "plain"))
  assert_eq(h.undo_depth(), 4)
}

///|
test "explicit boundary closes a typing group" {
  let h = int_history()
  ignore(h.record(1, "typing", group="field"))
  h.break_group()
  ignore(h.record(2, "typing", group="field"))
  assert_eq(h.undo_depth(), 2)
}

///|
test "saving is a hard coalescing boundary" {
  let h = int_history()
  ignore(h.record(1, "typing", group="field"))
  ignore(h.mark_saved())
  ignore(h.record(2, "typing", group="field"))
  assert_eq(h.undo_depth(), 2)
  ignore(h.undo())
  assert_eq(h.state(), 1)
  assert_true(!h.is_dirty())
}

///|
test "undo redo and same-index navigation close groups" {
  let h = int_history()
  ignore(h.record(1, "edit", group="field"))
  ignore(h.undo())
  ignore(h.redo())
  ignore(h.record(2, "edit", group="field"))
  assert_eq(h.undo_depth(), 2)
  ignore(h.jump_to(2))
  ignore(h.record(3, "edit", group="field"))
  assert_eq(h.undo_depth(), 3)
}

///|
test "rolled-back transaction still establishes a grouping boundary" {
  let h = int_history()
  ignore(h.record(1, "edit", group="field"))
  ignore(h.begin("preview"))
  ignore(h.record(9, "temp", group="field"))
  ignore(h.rollback())
  ignore(h.record(2, "edit", group="field"))
  assert_eq(h.undo_depth(), 2)
}

///|
test "no-op records preserve redo and do not relabel revisions" {
  let h = int_history()
  ignore(h.record(1, "original", group="field"))
  assert_eq(h.record(1, "no-op", group="other"), Ok(false))
  assert_eq(h.undo_label(), Some("original"))
  ignore(h.record(2, "next", group="field"))
  assert_eq(h.undo_depth(), 1)
}

///|
test "resizing and clearing establish grouping boundaries" {
  let h = int_history()
  ignore(h.record(1, "edit", group="field"))
  ignore(h.set_capacity(10))
  ignore(h.record(2, "edit", group="field"))
  assert_eq(h.undo_depth(), 2)
  ignore(h.clear())
  ignore(h.record(3, "edit", group="field"))
  ignore(h.undo())
  assert_eq(h.state(), 2)
}
