///|
test "nested document edits round-trip savepoint redo and deeply isolated arrays" {
  let h = new_editor()
  let supplied = document("Article", ["Keep this"])
  h.begin("Publish preparation").unwrap()
  assert_true(h.record(supplied, "Draft").unwrap())
  supplied.sections[0].lines.push("Caller mutation")
  assert_eq(h.state().sections[0].lines, ["Keep this"])
  h.begin("Alternative").unwrap()
  ignore(h.record(document("Rejected", ["Discard"]), "Preview").unwrap())
  assert_true(h.rollback().unwrap())
  assert_true(h.commit().unwrap())
  assert_eq(h.undo_depth(), 1)
  h.mark_saved().unwrap()
  let saved_id = h.revision_id()
  ignore(h.record(document("Revision", ["New line"]), "Revise").unwrap())
  ignore(h.undo().unwrap())
  let restored = reopen(h.export_session(fn(doc) { doc.to_json() }).unwrap()).unwrap()
  assert_true(!restored.is_dirty())
  assert_eq(restored.saved_revision_id(), Some(saved_id))
  assert_eq(restored.redo_label(), Some("Revise"))
  let returned = restored.state()
  returned.sections[0].lines.clear()
  assert_eq(restored.state().sections[0].lines, ["Keep this"])
  assert_true(restored.redo().unwrap())
  assert_true(restored.is_dirty())
  assert_eq(restored.state().title, "Revision")
  assert_true(restored.undo().unwrap())
  assert_true(!restored.is_dirty())
}

///|
test "codec rejects obsolete or invalid historical documents before replacement" {
  let h = new_editor()
  ignore(h.record(document("Current", ["Valid"]), "Edit").unwrap())
  let session = h
    .export_session(fn(doc) {
      if doc.title == "Untitled" {
        { "schema": 2, "title": "Old schema", "sections": [] }
      } else {
        doc.to_json()
      }
    })
    .unwrap()
  assert_true(reopen(session) is Err(_))
  assert_eq(h.state().title, "Current")
  assert_true(h.undo().unwrap())
  assert_eq(h.state().title, "Untitled")
  assert_true(
    decode_document({ "schema": 1.5, "title": "Bad", "sections": [] }) is Err(_),
  )
  assert_true(
    decode_document({
      "schema": 1,
      "title": "Bad",
      "sections": [{ "heading": "Notes", "lines": [42] }],
    })
    is Err(_),
  )
}

///|
test "editing after restored undo branches with fresh identity and preserves pruning semantics" {
  let h = new_editor()
  ignore(h.record(document("First", ["A"]), "First").unwrap())
  h.mark_saved().unwrap()
  let saved_id = h.revision_id()
  ignore(h.record(document("Second", ["B"]), "Second").unwrap())
  let discarded_id = h.revision_id()
  ignore(h.undo().unwrap())
  let restored = reopen(h.export_session(fn(doc) { doc.to_json() }).unwrap()).unwrap()
  ignore(restored.record(document("New branch", ["C"]), "Branch").unwrap())
  assert_true(!restored.can_redo())
  assert_true(restored.revision_id() > discarded_id)
  restored.set_capacity(1).unwrap()
  ignore(restored.record(document("Newest", ["D"]), "Newest").unwrap())
  assert_eq(restored.saved_revision_id(), Some(saved_id))
  assert_true(restored.is_dirty())
  let pruned = reopen(
    restored.export_session(fn(doc) { doc.to_json() }).unwrap(),
  ).unwrap()
  assert_eq(pruned.undo_depth(), 1)
  assert_true(pruned.undo().unwrap())
  assert_eq(pruned.state().title, "New branch")
  assert_true(pruned.is_dirty())
}
