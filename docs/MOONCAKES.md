# MoonUndo

Generic snapshot undo/redo and transactional history, implemented in MoonBit. Applications supply their own data type, deep-copy function and semantic equality. No UI framework, JavaScript runtime or network service is required by the library.

## Install

Requires MoonBit compiler/core 0.10.14 or newer. This release is tested with `moonc v0.10.14+7d59c7ec9` on JavaScript and Wasm GC.

From an existing MoonBit project:

```sh
moon add YeeHh2004/moonundo@0.2.2
```

Add this package import to `moon.pkg`:

```moonbit
import {
  "YeeHh2004/moonundo" @undo,
}
```

For a new project, create one with `moon new my-editor` first. Add the import to the package containing your code (for example `cmd/main/moon.pkg`).

## Minimal example

```moonbit
fn main {
  let history = @undo.History::new(
    ["draft"],
    copy=fn(items) { items.copy() },
    equal=fn(a, b) { a == b },
    limit=20,
  ).unwrap()
  history.begin("Prepare article").unwrap()
  ignore(history.record(["draft", "reviewed"], "Review").unwrap())
  ignore(history.record(["draft", "reviewed", "ready"], "Ready").unwrap())
  ignore(history.commit().unwrap())
  ignore(history.undo().unwrap())
  println(history.state()) // ["draft"]
}
```

Run the containing package with `moon run . --target wasm-gc` (or `moon run cmd/main --target wasm-gc` when it lives there); `--target js` also works. The published module includes a runnable typed example in `examples/typed`. A complete independent document application and registry-install verification script are available in the [GitHub repository](https://github.com/YeeHh2004/moonundo/tree/main/examples/consumer).

## Core behavior

- `record`, `undo`, `redo`, `jump_to`: isolated snapshots, labels, bounded history and branching after undo.
- `begin`, `commit`, `rollback`: up to 64 nested previews; an outer commit creates one undo step.
- `record(..., group="typing")` and `break_group`: explicit coalescing; navigation and saving close groups.
- `mark_saved`, `is_dirty`: track revision identity. Mark saved only after successful storage I/O.
- `export_session` and `restore_session`: application codecs, metadata validation, savepoint/redo preservation. Restore returns a new history; keep the old one on failure.
- `JsonEditor`: incremental JSON adapter implemented in MoonBit; optional `include_session:false` avoids returning a full archive on each edit.

Mutable nested data requires deep copying at every mutable level. The library returns copies, but relies on the supplied copy/equality/codecs being pure and correct. Handle `Result` errors in production instead of unconditionally unwrapping them.

## Scope and license

Single-user, full-snapshot history: capacity counts undoable steps, not bytes. Large state and nested transaction frames require appropriate memory budgeting. No CRDT collaboration or rollback of external side effects. The optional JSON adapter limits a request to 2 million UTF-16 units and depth 64; typed `History[T]` does not impose those JSON limits.

Original code: Apache-2.0. AI-assisted development is disclosed. No existing undo library was ported. `LICENSE`, `NOTICE.md` and the full upstream notices in `licenses/` accompany the published package. JavaScript browser/CLI hosts and build/test tooling are distributed separately through GitHub and Releases; the Mooncakes archive contains MoonBit implementation and examples.

[Source and development history](https://github.com/YeeHh2004/moonundo) · [Full integration guide](https://github.com/YeeHh2004/moonundo/blob/main/docs/DEVELOPMENT.md) · [Reproducible tests](https://github.com/YeeHh2004/moonundo/actions) · [Interactive examples](https://yeehh2004.github.io/moonundo/)
