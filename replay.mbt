///|
priv suberror ReplayError {
  ReplayError(String)
}

///|
fn json_copy(value : Json) -> Json {
  match value {
    Array(items) => Json::array(items.map(json_copy))
    Object(fields) => {
      let cloned : Map[String, Json] = Map([])
      for key, item in fields {
        cloned[key] = json_copy(item)
      }
      Json::object(cloned)
    }
    _ => value
  }
}

///|
fn[T] require(result : Result[T, String]) -> T raise ReplayError {
  match result {
    Ok(v) => v
    Err(message) => raise ReplayError(message)
  }
}

///|
fn field(value : Json, key : String) -> Json raise ReplayError {
  guard value is Object(fields) else { raise ReplayError("expected an object") }
  match fields.get(key) {
    Some(v) => v
    None => raise ReplayError("missing field: " + key)
  }
}

///|
fn optional(value : Json, key : String, fallback : Json) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(fallback)
    _ => fallback
  }
}

///|
fn string_field(value : Json, key : String) -> String raise ReplayError {
  guard field(value, key) is String(text) else {
    raise ReplayError("expected string: " + key)
  }
  text
}

///|
fn apply_command(h : History[Json], command : Json) -> Unit raise {
  let name = string_field(command, "op")
  match name {
    "record" => {
      let label : String = @json.from_json(optional(command, "label", "Edit"))
      let group : String = @json.from_json(optional(command, "group", ""))
      ignore(require(h.record(field(command, "value"), label, group~)))
    }
    "undo" => ignore(require(h.undo()))
    "redo" => ignore(require(h.redo()))
    "jump" =>
      ignore(require(h.jump_to(require(exact_int(field(command, "index"))))))
    "begin" => require(h.begin(string_field(command, "label")))
    "commit" => ignore(require(h.commit()))
    "rollback" => ignore(require(h.rollback()))
    "save" => require(h.mark_saved())
    "forget_saved" => h.forget_saved()
    "break_group" => h.break_group()
    "clear" => require(h.clear())
    "capacity" =>
      require(h.set_capacity(require(exact_int(field(command, "limit")))))
    "reset" => require(h.reset(field(command, "value")))
    _ => raise ReplayError("unknown operation: " + name)
  }
}

///|
/// Portable JSON adapter for CLI/JS. Replays at most 2000 commands atomically.
/// Errors produce no output session; callers keep their previous document.
pub fn replay(text : String) -> String {
  try {
    if text.length() > 2000000 {
      raise ReplayError("request exceeds 2 million UTF-16 units")
    }
    let request = @json.parse(text)
    let h = match optional(request, "session", Json::null()) {
      Null => {
        let limit = require(exact_int(optional(request, "limit", 100)))
        require(
          History::new(
            field(request, "initial"),
            copy=json_copy,
            equal=fn(a, b) { a == b },
            limit~,
          ),
        )
      }
      session =>
        require(
          restore_session(session, fn(v) { Ok(json_copy(v)) }, copy=json_copy, equal=fn(
            a,
            b,
          ) {
            a == b
          }),
        )
    }
    guard field(request, "commands") is Array(commands) else {
      raise ReplayError("commands must be an array")
    }
    if commands.length() > 2000 {
      raise ReplayError("at most 2000 commands per request")
    }
    for command in commands {
      apply_command(h, command)
    }
    let session = match h.export_session(json_copy) {
      Ok(v) => v
      Err(_) => Json::null()
    }
    let response : Json = {
      "ok": true,
      "state": h.state(),
      "dirty": h.is_dirty(),
      "can_undo": h.can_undo(),
      "can_redo": h.can_redo(),
      "undo_label": h.undo_label(),
      "redo_label": h.redo_label(),
      "undo_depth": h.undo_depth(),
      "redo_depth": h.redo_depth(),
      "transaction_depth": h.transaction_depth(),
      "revision_id": h.revision_id(),
      "timeline": h.timeline(),
      "session": session,
    }
    response.stringify()
  } catch {
    error => {
      let response : Json = { "ok": false, "error": error.to_string() }
      response.stringify()
    }
  }
}
