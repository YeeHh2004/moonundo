///|
/// Incremental JSON adapter. Owns a history, not a growing replay script.
pub struct JsonEditor {
  priv history : History[Json]
  priv include_session : Bool
}

///|
/// Accept {initial, limit?} or {session}; construction never executes commands.
pub fn JsonEditor::new(text : String) -> Result[JsonEditor, String] {
  try {
    let request = parse_request(text)
    if request is Object(fields) && fields.contains("commands") {
      return Err("JsonEditor construction does not accept replay commands")
    }
    let include_session : Bool = @json.from_json(
      optional(request, "include_session", true),
    )
    Ok({ history: history_from_request(request), include_session, })
  } catch {
    error => Err(error_message(error))
  }
}

///|
/// Return an isolated JSON snapshot of state, metadata and committed session.
pub fn JsonEditor::status(self : JsonEditor) -> String {
  status_json(self.history, include_session=self.include_session).stringify()
}

///|
/// Execute one command. A rejected command leaves the history unchanged.
/// prepare_save exports a clean candidate without marking the live state saved;
/// the host persists it, then sends save only after successful synchronous I/O.
pub fn JsonEditor::dispatch(self : JsonEditor, text : String) -> String {
  try {
    let command = parse_request(text)
    let op = string_field(command, "op")
    if op == "prepare_save" || op == "export" {
      let session = require(self.history.export_session(fn(v) { v }))
      if op == "prepare_save" && session is Object(fields) {
        fields["saved_id"] = self.history.revision_id().to_json()
      }
      // Validate the final candidate, including the new savepoint's width.
      let request : Json = if self.include_session {
        { "session": session }
      } else {
        { "session": session, "include_session": false }
      }
      ignore(parse_request(request.stringify()))
      let response : Json = { "ok": true, "session": session }
      return response.stringify()
    }
    if op != "status" {
      apply_command(self.history, command)
    }
    self.status()
  } catch {
    error => {
      let response : Json = { "ok": false, "error": error_message(error) }
      response.stringify()
    }
  }
}

///|
fn parse_request(text : String) -> Json raise {
  if text.length() > 2000000 {
    raise ReplayError("request exceeds 2 million UTF-16 units")
  }
  let request = @json.parse(text)
  validate_json(request, 0)
  request
}
