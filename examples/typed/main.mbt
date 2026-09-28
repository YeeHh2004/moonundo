///|
priv struct Document {
  title : String
  tags : Array[String]
} derive(Eq, ToJson)

///|
fn clone_document(doc : Document) -> Document {
  { title: doc.title, tags: doc.tags.copy(), }
}

///|
fn create_editor() -> @undo.History[Document] {
  @undo.History::new(
    { title: "Untitled", tags: [], },
    copy=clone_document,
    equal=fn(a, b) { Eq::equal(a, b) },
    limit=50,
  ).unwrap()
}

///|
fn main {
  let history = create_editor()
  ignore(history.begin("Publish preparation"))
  ignore(history.record({ title: "My article", tags: [], }, "Rename"))
  ignore(history.record({ title: "My article", tags: ["moonbit"], }, "Tag"))
  ignore(history.commit())
  println(ToJson::to_json(history.state()).stringify())
  ignore(history.undo())
  println(ToJson::to_json(history.state()).stringify())
}
