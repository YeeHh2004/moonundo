# Changelog

## 0.1.1 — 2026-09-28

- Return JSON `undo_label` and `redo_label` as string-or-null, matching the documented bridge protocol. The initial adapter used generic Option serialization, which wrapped a present label in a single-element array. Typed MoonBit APIs and history behavior are unchanged.
- Check both present and absent label shapes in compiled CLI integration tests.

## 0.1.0 — 2026-09-28

- Initial generic snapshot history, timeline navigation, transactions, savepoints, edit grouping and validated sessions.
- JSON replay adapter, Node CLI, three browser examples, standalone consumption checks, generated-model regression tests and cross-platform/browser CI.
