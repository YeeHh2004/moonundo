///|
pub fn replay(text : String) -> String {
  @undo.replay(text)
}

///|
fn main {
  ()
}

///|
pub fn reduce(text : String) -> String {
  @reducers.reduce(text)
}
