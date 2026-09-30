///|
priv struct Section {
  heading : String
  lines : Array[String]
} derive(Eq, ToJson, @json.FromJson)

///|
priv struct Document {
  schema : Int
  title : String
  sections : Array[Section]
} derive(Eq, ToJson, @json.FromJson)

///|
extend Document with ToJson::{to_json}

///|
fn copy_document(doc : Document) -> Document {
  {
    schema: doc.schema,
    title: doc.title,
    sections: doc.sections.map(fn(section) {
      { heading: section.heading, lines: section.lines.copy(), }
    }),
  }
}

///|
// The application's codec validates its schema on every historical snapshot.
fn decode_document(value : Json) -> Result[Document, String] {
  guard value is Object(fields) && fields.get("schema") == Some((1).to_json()) else {
    return Err("unsupported document schema; expected 1")
  }
  let doc : Document = @json.from_json(value) catch {
    _ => return Err("expected a document with title, sections and string lines")
  }
  if doc.title == "" || doc.title.length() > 200 || doc.sections.length() > 100 {
    return Err("invalid document title or section count")
  }
  for section in doc.sections {
    if section.lines.length() > 1000 {
      return Err("section exceeds 1000 lines")
    }
  }
  Ok(doc)
}

///|
fn document(title : String, lines : Array[String]) -> Document {
  { schema: 1, title, sections: [{ heading: "Notes", lines, }], }
}

///|
fn new_editor() -> @undo.History[Document] {
  @undo.History::new(
    document("Untitled", []),
    copy=copy_document,
    equal=fn(a, b) { a == b },
    limit=20,
  ).unwrap()
}

///|
fn reopen(session : Json) -> Result[@undo.History[Document], String] {
  @undo.restore_session(session, decode_document, copy=copy_document, equal=fn(
    a,
    b,
  ) {
    a == b
  })
}

///|
fn main {
  let h = new_editor()
  h.begin("Write article").unwrap()
  ignore(
    h.record(document("MoonBit notes", ["First paragraph"]), "Draft").unwrap(),
  )
  h.begin("Try an alternative").unwrap()
  ignore(
    h.record(document("Rejected draft", ["Temporary"]), "Preview").unwrap(),
  )
  ignore(h.rollback().unwrap())
  ignore(h.commit().unwrap())
  // A real host calls mark_saved only after successfully persisting its data.
  h.mark_saved().unwrap()
  ignore(
    h
    .record(document("Revised notes", ["Revised paragraph"]), "Revise")
    .unwrap(),
  )
  ignore(h.undo().unwrap())
  let saved = h.export_session(fn(doc) { doc.to_json() }).unwrap()
  let restored = reopen(saved).unwrap()
  println("Reopened saved revision (clean):")
  println(restored.state().to_json().stringify())
  ignore(restored.redo().unwrap())
  println("Redo after reopening (unsaved revision):")
  println(restored.state().to_json().stringify())
}
