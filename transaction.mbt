///|
priv struct Transaction[T] {
  before : T
  label : String
}

///|
pub fn[T] History::transaction_depth(self : History[T]) -> Int {
  self.transactions.length()
}

///|
/// Nested transactions preview state, but only an outer commit creates history.
pub fn[T] History::begin(
  self : History[T],
  label : String,
) -> Result[Unit, String] {
  if self.transactions.length() >= 64 {
    return Err("transaction nesting limit is 64")
  }
  self.merge_allowed = false
  self.transactions.push({ before: (self.copy)(self.live), label, })
  Ok(())
}

///|
/// Returns whether the frame changed state. Empty/net-zero commits preserve redo.
pub fn[T] History::commit(self : History[T]) -> Result[Bool, String] {
  let n = self.transactions.length()
  if n == 0 {
    return Err("no active transaction")
  }
  let frame = self.transactions[n - 1]
  let changed = !(self.same)(frame.before, self.live)
  if n == 1 && changed && self.next_id == 2147483647 {
    return Err("revision identifier space exhausted")
  }
  ignore(self.transactions.pop())
  if n > 1 {
    return Ok(changed)
  }
  let after = (self.copy)(self.live)
  self.live = (self.copy)(frame.before)
  self.record(after, frame.label)
}

///|
/// Cancel only the innermost frame; committed timeline and future stay intact.
pub fn[T] History::rollback(self : History[T]) -> Result[Bool, String] {
  match self.transactions.pop() {
    None => Err("no active transaction")
    Some(frame) => {
      let changed = !(self.same)(self.live, frame.before)
      self.live = (self.copy)(frame.before)
      Ok(changed)
    }
  }
}
