///|
priv struct StoredRevision {
  id : Int
  label : String
  value : Json
} derive(ToJson, @json.FromJson)

///|
priv struct Session {
  version : Int
  limit : Int
  cursor : Int
  next_id : Int
  saved_id : Int?
  revisions : Array[StoredRevision]
} derive(ToJson, @json.FromJson)

///|
/// The codec owns the schema of T. Active previews cannot be persisted.
pub fn[T] History::export_session(
  self : History[T],
  encode : (T) -> Json,
) -> Result[Json, String] {
  if self.transaction_depth() != 0 {
    return Err("commit or rollback before export")
  }
  let session : Session = {
    version: 1,
    limit: self.limit,
    cursor: self.cursor,
    next_id: self.next_id,
    saved_id: self.saved_id,
    revisions: self.revisions.map(fn(r) {
      { id: r.id, label: r.label, value: encode((self.copy)(r.value)), }
    }),
  }
  Ok(ToJson::to_json(session))
}

///|
/// Restore validates metadata before constructing a new history. Edit groups close.
pub fn[T] restore_session(
  value : Json,
  decode : (Json) -> Result[T, String],
  copy~ : (T) -> T,
  equal~ : (T, T) -> Bool,
) -> Result[History[T], String] {
  guard value is Object(fields) else { return Err("session must be an object") }
  for key in ["version", "limit", "cursor", "next_id"] {
    guard fields.get(key) is Some(number) && exact_int(number) is Ok(_) else {
      return Err("session metadata requires exact 32-bit integers")
    }
  }
  if fields.get("saved_id") is Some(number) &&
    number != Json::null() &&
    exact_int(number) is Err(_) {
    return Err("saved_id requires an exact integer or null")
  }
  if fields.get("revisions") is Some(Array(items)) {
    for item in items {
      guard item is Object(entry) &&
        entry.get("id") is Some(id) &&
        exact_int(id) is Ok(_) else {
        return Err("revision id requires an exact integer")
      }
    }
  }
  let session : Session = @json.from_json(value) catch {
    _ => return Err("invalid session field types")
  }
  if session.version != 1 {
    return Err("unsupported session version")
  }
  if session.limit < 1 || session.limit > 10000 {
    return Err("invalid session capacity")
  }
  if session.revisions.is_empty() ||
    session.revisions.length() > session.limit + 1 {
    return Err("invalid revision count")
  }
  if session.cursor < 0 || session.cursor >= session.revisions.length() {
    return Err("invalid session cursor")
  }
  if session.next_id < 1 {
    return Err("invalid next revision identifier")
  }
  if session.saved_id is Some(id) && (id < 0 || id >= session.next_id) {
    return Err("invalid saved revision identifier")
  }
  let revisions : Array[Revision[T]] = []
  let mut previous = -1
  for stored in session.revisions {
    if stored.id <= previous || stored.id >= session.next_id {
      return Err("revision identifiers must be increasing and below next_id")
    }
    previous = stored.id
    let decoded = match decode(stored.value) {
      Ok(v) => v
      Err(message) => return Err("invalid revision value: " + message)
    }
    revisions.push({
      value: copy(decoded),
      label: stored.label,
      group: "",
      id: stored.id,
    })
  }
  Ok({
    copy,
    same: equal,
    revisions,
    cursor: session.cursor,
    live: copy(revisions[session.cursor].value),
    merge_allowed: false,
    saved_id: session.saved_id,
    next_id: session.next_id,
    limit: session.limit,
    transactions: [],
  })
}

///|
fn exact_int(value : Json) -> Result[Int, String] {
  guard value is Number(n, ..) else { return Err("expected integer") }
  if n.is_nan() || n < -2147483648.0 || n > 2147483647.0 {
    return Err("integer out of range")
  }
  let i = n.to_int()
  if i.to_double() != n {
    return Err("fractional integer")
  }
  Ok(i)
}
