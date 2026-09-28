# Design and scope

History[T] accepts a pure deep-copy function and a pure semantic equality function. Inputs and returned states are copied; applications retain their own data model. Full snapshots trade memory for simple, deterministic rollback. A limit bounds the number of undoable revisions, not byte size. Copy-on-write or immutable values may use identity copy when genuinely immutable.

Implemented: bounded history navigation; nested transactions with commit/rollback; saved-revision checkpoints; explicit coalescing boundaries; validated JSON session export/restore through caller codecs; a JSON adapter, CLI replay runner, and three interactive browser examples. Core runs on JS and Wasm GC without network, clock, DOM, CRDT or host runtime dependencies. The CLI and demo host use Node; example reducers are in a separate package and are not dependencies of History[T].

History changes application memory only. It cannot undo external file writes, HTTP requests, payments or other side effects. It is single-user linear history, not collaborative undo. New edits after undo discard the future branch. Transactions preview edits but add only one revision at outer commit; rollback leaves committed history intact.

Savepoints identify revisions, not merely equal values. Committing equal state is a no-op. Coalescing must not swallow a saved revision or cross undo/redo, transaction, explicit break or restored-session boundaries. Restore must validate all metadata before creating a usable history.

## Operational contracts

- A capacity of N retains at most N+1 committed snapshots. When shrinking in the middle of history, preserve the current revision, then the nearest past, then as much future as fits. Up to 64 nested transaction baselines and the current live state are additional copies.
- Revisions receive monotonically increasing 32-bit identifiers. Exhaustion is an explicit error, never wraparound. `clear` keeps the current id; `reset` allocates a fresh one and marks it clean. `forget_saved` disconnects the savepoint even during a preview.
- Nested commit merges preview into its parent. Inner rollback only cancels that frame. Net-zero outer transactions add no revision and preserve redo. Navigation and destructive history maintenance are rejected while a transaction is open.
- A record equal to the current state is a no-op, retains redo, label and group. A true new edit after undo drops redo. Explicit grouped records allocate fresh revision ids while replacing the latest group snapshot. Returning to an old value through grouped edits still represents a distinct revision; groups are not algebraically cancelled.
- `mark_saved` is a statement by the host application, not disk I/O. A saved id may refer to a pruned or discarded revision, and should remain dirty rather than misidentifying equal content on another branch as saved.
- `state`, record inputs and revision codec inputs are copied. Correct isolation depends on the supplied copy function. Equality and all codecs must be pure; a codec's validation of T is the application's responsibility.
- Session version 1 retains ids, labels, limit, cursor, next id and nullable saved id. Groups and active transaction frames are deliberately not persisted. Unknown metadata fields are ignored for additive compatibility; missing required fields, fractional integers, invalid ranges or unordered/duplicate ids fail. An omitted saved id is treated as unknown.
- Core operations are linear in retained history when recording/trimming; state copying adds the cost of copying T. Undo/redo move a cursor and copy one state. Snapshots favor predictability over delta-compression efficiency.
- Browser demos replay a bounded operation script on each interaction for a pure JSON bridge. At 1,500 commands, a completed session becomes the new replay baseline and the active edit group ends; the core library itself does not replay scripts. Demo requests are limited as described in JSON.md.
- Import replaces a demo only after the session and every application snapshot validate. Local save publishes the new in-memory savepoint only after localStorage succeeds. Import/restore deliberately replace current working history; export important unsaved work first.
