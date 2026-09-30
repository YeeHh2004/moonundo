///|
/// Incremental JSON adapter. Owns a history, not a growing replay script.
pub struct JsonEditor {
  priv history : History[Json]
}

///|
/// Accept {initial, limit?} or {session}; construction never executes commands.
pub fn JsonEditor::new(text : String) -> Result[JsonEditor, String] {
  try {
    let request = parse_request(text)
    if request is Object(fields) && fields.contains("commands") {
      return Err("JsonEditor construction does not accept replay commands")
    }
    Ok({ history: history_from_request(request), })
  } catch {
    error => Err(error_message(error))
  }
}

///|
/// Return an isolated JSON snapshot of state, metadata and committed session.
pub fn JsonEditor::status(self : JsonEditor) -> String {
  status_json(self.history).stringify()
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
      let session = require(self.history.export_session(json_copy))
      // Never hand the host a JSON archive that this adapter cannot reopen.
      let request : Json = { "session": session }
      ignore(parse_request(request.stringify()))
      if op == "prepare_save" && session is Object(fields) {
        fields["saved_id"] = self.history.revision_id().to_json()
      }
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
