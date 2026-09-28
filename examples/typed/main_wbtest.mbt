///|
test "external package uses History with its own mutable document type" {
  let h = create_editor()
  let supplied : Document = { title: "Draft", tags: ["writing"], }
  ignore(h.record(supplied, "Create draft"))
  supplied.tags.push("caller mutation")
  let returned = h.state()
  returned.tags.clear()
  assert_eq(h.state().tags, ["writing"])
  ignore(h.undo())
  assert_eq(h.state().title, "Untitled")
  ignore(h.redo())
  assert_eq(h.state().tags, ["writing"])
}
