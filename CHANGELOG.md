# Changelog

## 0.2.1 — 2026-09-30

- Add optional `include_session: false` to incremental editors and use it in the browser. Ordinary edits return current state and metadata without copying/serializing the entire archive. Default responses and v1 sessions remain compatible; explicit export/save preparation still return complete histories.
- Validate the final save candidate after updating saved_id, including the compact-mode restore envelope, fixing a request-size boundary that could otherwise produce an unreadable saved file.
- Replace the minimal generated consumer with a complete standalone MoonBit document module: nested mutable data, typed codecs, nested rollback, saved revision/redo restoration, invalid historical schemas, branching and pruning. Run three integration tests and the example on both backends.
- Add reproducible 100/500-task and nested-document workloads, raw measurements, performance/space guidance, and a CI artifact. Compare final states and archives on every trial; no machine-dependent timing threshold.
- 56 MoonBit tests on each backend, 3 standalone-consumer tests (59 total in its workspace), and 31 Node tests; existing browser acceptance remains enabled.

## 0.2.0 — 2026-09-30

- Add incremental JsonEditor and bounded ESM handle lifecycle; migrate all three browser examples away from replaying a growing command log. Long transactions remain cancellable and continuous groups no longer split at a log compaction threshold.
- Add non-mutating export / prepare_save; only mark a revision saved after storage succeeds. Reject archives that cannot be reopened under JSON adapter limits.
- Preserve new edits during deferred file imports, validate every imported application snapshot, release rejected/replaced handles, and support UTF-8 archive files up to 8 MB.
- Preflight all session metadata before allocating typed revisions or invoking user decoders. Preserve detailed adapter/domain error messages.
- Bound both file and stdin CLI reads while streaming; add --version and missing-build guidance.
- Include full pinned MoonBit core LICENSE/NOTICE in source, web distribution and ZIPs. Emit build provenance and engine hashes.
- Add clean-checkout packaging, one-command verification, external consumer version alignment, distribution checks, long-edit regressions and expanded browser acceptance. Existing generic History[T] APIs and v1 sessions remain compatible.

## 0.1.1 — 2026-09-28

- Return JSON `undo_label` and `redo_label` as string-or-null, matching the documented bridge protocol. The initial adapter used generic Option serialization, which wrapped a present label in a single-element array. Typed MoonBit APIs and history behavior are unchanged.
- Check both present and absent label shapes in compiled CLI integration tests.

## 0.1.0 — 2026-09-28

- Initial generic snapshot history, timeline navigation, transactions, savepoints, edit grouping and validated sessions.
- JSON replay adapter, Node CLI, three browser examples, standalone consumption checks, generated-model regression tests and cross-platform/browser CI.
