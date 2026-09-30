# JSON bridge protocol v1

`replay(text: String) -> String` is a pure request/response adapter. It creates a temporary history, executes the commands in order, and returns either `{ "ok": false, "error": "..." }` or the resulting state and session. A failure does not expose partial output, mutate a previous request, or perform I/O.

Start with `{ "initial": <any JSON>, "limit": 50, "commands": [...] }`, or `{ "session": <exported session>, "commands": [...] }`. A non-null session takes precedence over initial and limit. Each request has at most 2,000 commands and 2 million UTF-16 code units; JSON nesting must not exceed 64. JSON numbers use IEEE-754 semantics and must be finite with absolute value at most 9,007,199,254,740,991. Use strings for larger exact numbers. Generic `History[T]` is not subject to these JSON adapter limits.

| op | Additional fields | Result |
| --- | --- | --- |
| record | `value`, optional `label` (Edit), `group` (empty) | Update current state |
| undo / redo | none | Navigate if available; empty stack is a no-op |
| jump | `index` (integer) | Navigate current timeline index |
| begin | `label` | Begin nested preview |
| commit / rollback | none | Commit/cancel current frame |
| save / forget_saved | none | Declare or disconnect savepoint; no I/O |
| break_group | none | End a coalescing group |
| capacity | `limit` (integer) | Resize retained history |
| clear | none | Keep only current committed revision |
| reset | `value` | Create a fresh, clean baseline |

Successful output includes `state`, `dirty`, `can_undo`, `can_redo`, string-or-null `undo_label` and `redo_label`, depths, `transaction_depth`, `capacity`, `revision_id`, `timeline`, and `session`. An active preview yields `session: null` until commit/rollback. `undo_depth` and `redo_depth` describe committed history even while navigation is disabled.

Session v1 shape:

```json
{
  "version": 1, "limit": 50, "cursor": 1, "next_id": 2, "saved_id": 0,
  "revisions": [
    {"id": 0, "label": "Initial", "value": {"count": 0}},
    {"id": 1, "label": "Increment", "value": {"count": 1}}
  ]
}
```

The browser's downloadable file wraps this session in `{ "format": "moonundo-demo", "version": 1, "kind": "settings|tasks|canvas", "session": ... }`. This wrapper is application-specific; pass its `session` field to the generic adapter. The example `reduce` export takes `{ kind, state, action }` and returns `{ok,state}` or `{ok:false,error}`. It implements domain edits separately from core undo semantics.

## Incremental editor API (0.2.0)

MoonBit: `JsonEditor::new(text) -> Result[JsonEditor, String]`, `editor.dispatch(text) -> String`, `editor.status() -> String`. Constructor input is `{initial,limit?}` or `{session}`; a `commands` property is rejected. Methods use the same status schema and operations as replay, except these additional commands:

Both constructor forms also accept optional `include_session: false`. This omits the `session` property from status and ordinary command responses, avoiding a copy and serialization of every historical snapshot on each edit. Current `state`, timeline, savepoint status and all other metadata remain available. Explicit `export` and `prepare_save` still return complete archives. The default is `true` for backward compatibility, and `replay` remains unchanged. Browser demos use `false`; consumers of `EditorModel` must call `exportSession()` when they need an archive. Only booleans are accepted for this option.

| op | Result | Mutates history? |
| --- | --- | --- |
| status | Full status object | No |
| export | `{ok:true,session}` with original savepoint | No |
| prepare_save | `{ok:true,session}` with copied saved_id set to the current revision | No |

For browser/Node ESM, `open_editor(text)` returns JSON `{ok:true,handle}`; `dispatch_editor(handle,text)` returns JSON status/error; `close_editor(handle)` returns whether that handle was live. At most 64 editors may be open. Replacing/closing an editor releases its capacity and references; handles are never reused. Keep handles private to the owning app, validate success responses, and close editors in `finally` when finished. Unknown/closed handles return an error. These are in-process handles, not network authentication tokens.

There is no total operation-count limit on a live editor. Each request still has the 2-million-code-unit / depth-64 constraints; export and prepare_save check the final candidate after changing saved_id when applicable, including the compact-mode option needed to reopen it. Accumulating large snapshots can exceed that archive limit: reduce history capacity or use typed codecs/storage suited to the application. Rejected export/save preparation leaves live state unchanged. Browser downloads use compact JSON; the import file limit is 8 MB to accommodate UTF-8 text. Version 1 session files from 0.1.x remain supported.

To persist: prepare_save → synchronous storage of its returned session → save. If storage throws, omit save. For asynchronous storage, serialize edits or check revision identity before marking the live state saved; do not mark a different revision clean. `web/editor-model.mjs` is the tested synchronous localStorage integration.
