///|
/// Metadata-only timeline entry; no mutable user data is exposed.
pub struct RevisionInfo {
  index : Int
  revision_id : Int
  label : String
  current : Bool
} derive(ToJson)

///|
pub extend RevisionInfo with ToJson::{to_json}

///|
pub fn[T] History::timeline(self : History[T]) -> Array[RevisionInfo] {
  self.revisions.mapi(fn(i, r) {
    { index: i, revision_id: r.id, label: r.label, current: i == self.cursor, }
  })
}

///|
pub fn[T] History::undo_depth(self : History[T]) -> Int {
  self.cursor
}

///|
pub fn[T] History::redo_depth(self : History[T]) -> Int {
  self.revisions.length() - self.cursor - 1
}

///|
pub fn[T] History::capacity(self : History[T]) -> Int {
  self.limit
}

///|
pub fn[T] History::redo_label(self : History[T]) -> String? {
  if self.can_redo() {
    Some(self.revisions[self.cursor + 1].label)
  } else {
    None
  }
}

///|
/// Navigate by current timeline index, not by stable revision identifier.
pub fn[T] History::jump_to(
  self : History[T],
  index : Int,
) -> Result[Bool, String] {
  if index < 0 || index >= self.revisions.length() {
    return Err("timeline index out of range")
  }
  if index == self.cursor {
    return Ok(false)
  }
  self.cursor = index
  self.live = (self.copy)(self.revisions[index].value)
  Ok(true)
}

///|
/// Reducing capacity keeps current state, closest past first, then future.
pub fn[T] History::set_capacity(
  self : History[T],
  limit : Int,
) -> Result[Unit, String] {
  if limit < 1 || limit > 10000 {
    return Err("history limit must be between 1 and 10000")
  }
  self.limit = limit
  self.trim()
  Ok(())
}

///|
/// Forget navigation history while retaining current state and revision id.
pub fn[T] History::clear(self : History[T]) -> Result[Unit, String] {
  self.revisions = [self.revisions[self.cursor]]
  self.cursor = 0
  Ok(())
}
