///|
/// End a coalescing run explicitly, e.g. blur, pointer-up or a cursor move.
/// record(..., group="typing") coalesces only consecutive compatible edits.
pub fn[T] History::break_group(self : History[T]) -> Unit {
  self.merge_allowed = false
}
