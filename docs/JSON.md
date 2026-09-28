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

Successful output includes `state`, `dirty`, `can_undo`, `can_redo`, nullable `undo_label` and `redo_label`, depths, `transaction_depth`, `revision_id`, `timeline`, and `session`. An active preview yields `session: null` until commit/rollback. `undo_depth` and `redo_depth` describe committed history even while navigation is disabled.

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
