///|
/// Dirty means revision identity differs from saved, or a preview differs.
/// It does not prove a file was saved: call mark_saved only after successful I/O.
pub fn[T] History::is_dirty(self : History[T]) -> Bool {
  self.saved_id != Some(self.revision_id()) ||
  !(self.same)(self.live, self.revisions[self.cursor].value)
}

///|
pub fn[T] History::saved_revision_id(self : History[T]) -> Int? {
  self.saved_id
}

///|
pub fn[T] History::mark_saved(self : History[T]) -> Result[Unit, String] {
  if !self.transactions.is_empty() {
    return Err("cannot mark a preview as saved; commit or rollback first")
  }
  self.merge_allowed = false
  self.saved_id = Some(self.revision_id())
  Ok(())
}

///|
/// Disassociate history from any external saved state, e.g. an untitled document.
pub fn[T] History::forget_saved(self : History[T]) -> Unit {
  self.saved_id = None
}

///|
/// Load a new baseline, forgetting navigation and marking this revision clean.
pub fn[T] History::reset(
  self : History[T],
  initial : T,
  label? : String = "Loaded",
) -> Result[Unit, String] {
  if !self.transactions.is_empty() {
    return Err("cannot reset during a transaction")
  }
  if self.next_id == 2147483647 {
    return Err("revision identifier space exhausted")
  }
  let id = self.next_id
  self.next_id += 1
  self.revisions = [{ value: (self.copy)(initial), label, group: "", id, }]
  self.merge_allowed = false
  self.cursor = 0
  self.live = (self.copy)(initial)
  self.saved_id = Some(id)
  Ok(())
}
