# Design and scope

History[T] accepts a pure deep-copy function and a pure semantic equality function. Inputs and returned states are copied; applications retain their own data model. Full snapshots trade memory for simple, deterministic rollback. A limit bounds the number of undoable revisions, not byte size. Copy-on-write or immutable values may use identity copy when genuinely immutable.

Planned deliverable: bounded history navigation; nested transactions with commit/rollback; saved-revision checkpoints; explicit coalescing boundaries; validated JSON session export/restore through caller codecs; a JSON adapter, CLI replay runner, and three interactive browser examples. Core must run on JS and Wasm without network, clock, DOM, CRDT or host runtime dependencies.

History changes application memory only. It cannot undo external file writes, HTTP requests, payments or other side effects. It is single-user linear history, not collaborative undo. New edits after undo discard the future branch. Transactions preview edits but add only one revision at outer commit; rollback leaves committed history intact.

Savepoints identify revisions, not merely equal values. Committing equal state is a no-op. Coalescing must not swallow a saved revision or cross undo/redo, transaction, explicit break or restored-session boundaries. Restore must validate all metadata before creating a usable history.
