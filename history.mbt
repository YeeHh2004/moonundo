///|
priv struct Revision[T] {
  value : T
  label : String
  id : Int
}

///|
/// Single-user snapshot history. Supply a pure deep copy and semantic equality.
pub struct History[T] {
  priv copy : (T) -> T
  priv same : (T, T) -> Bool
  priv mut revisions : Array[Revision[T]]
  priv mut cursor : Int
  priv mut live : T
  priv mut saved_id : Int?
  priv mut next_id : Int
  priv mut limit : Int
  priv transactions : Array[Transaction[T]]
}

///|
/// Limit counts undoable revisions, not bytes. At most limit+1 states are held.
pub fn[T] History::new(
  initial : T,
  copy~ : (T) -> T,
  equal~ : (T, T) -> Bool,
  limit? : Int = 100,
) -> Result[History[T], String] {
  if limit < 1 || limit > 10000 {
    return Err("history limit must be between 1 and 10000")
  }
  Ok({
    copy,
    same: equal,
    revisions: [{ value: copy(initial), label: "Initial", id: 0, }],
    cursor: 0,
    live: copy(initial),
    transactions: [],
    saved_id: Some(0),
    next_id: 1,
    limit,
  })
}

///|
/// Return an isolated state, never the history-owned snapshot.
pub fn[T] History::state(self : History[T]) -> T {
  (self.copy)(self.live)
}

///|
pub fn[T] History::can_undo(self : History[T]) -> Bool {
  self.transactions.is_empty() && self.cursor > 0
}

///|
pub fn[T] History::can_redo(self : History[T]) -> Bool {
  self.transactions.is_empty() && self.cursor + 1 < self.revisions.length()
}

///|
/// Equal states are no-ops and preserve redo. Genuine edits drop the future.
pub fn[T] History::record(
  self : History[T],
  next : T,
  label : String,
) -> Result[Bool, String] {
  if (self.same)(self.live, next) {
    return Ok(false)
  }
  if !self.transactions.is_empty() {
    self.live = (self.copy)(next)
    return Ok(true)
  }
  if self.next_id == 2147483647 {
    return Err("revision identifier space exhausted")
  }
  let kept : Array[Revision[T]] = []
  for i in 0..<=self.cursor {
    kept.push(self.revisions[i])
  }
  kept.push({ value: (self.copy)(next), label, id: self.next_id, })
  self.next_id += 1
  self.revisions = kept
  self.cursor = kept.length() - 1
  self.live = (self.copy)(next)
  self.trim()
  Ok(true)
}

///|
fn[T] History::trim(self : History[T]) -> Unit {
  if self.revisions.length() <= self.limit + 1 {
    return
  }
  let start = (self.cursor - self.limit).max(0)
  let end = (start + self.limit + 1).min(self.revisions.length())
  self.revisions = self.revisions[start:end].to_owned()
  self.cursor -= start
}

///|
pub fn[T] History::undo(self : History[T]) -> Result[Bool, String] {
  if !self.transactions.is_empty() {
    return Err("cannot navigate during a transaction")
  }
  if !self.can_undo() {
    return Ok(false)
  }
  self.cursor -= 1
  self.live = (self.copy)(self.revisions[self.cursor].value)
  Ok(true)
}

///|
pub fn[T] History::redo(self : History[T]) -> Result[Bool, String] {
  if !self.transactions.is_empty() {
    return Err("cannot navigate during a transaction")
  }
  if !self.can_redo() {
    return Ok(false)
  }
  self.cursor += 1
  self.live = (self.copy)(self.revisions[self.cursor].value)
  Ok(true)
}

///|
pub fn[T] History::revision_id(self : History[T]) -> Int {
  self.revisions[self.cursor].id
}

///|
pub fn[T] History::undo_label(self : History[T]) -> String? {
  if self.can_undo() {
    Some(self.revisions[self.cursor].label)
  } else {
    None
  }
}
