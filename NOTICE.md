# Originality, references and tooling

MoonUndo is an original, AI-assisted implementation under Apache-2.0. It is not a line-by-line translation or port of Redux, Loro, event-graph-walker, or another undo library. These projects' source code has not been incorporated.

- Conceptual reference: [Redux – Implementing Undo History](https://redux.js.org/usage/implementing-undo-history), describing general undoable state. No code copied.
- Ecosystem comparison only: projects linked in [SELECTION.md](docs/SELECTION.md). Their licenses are not represented as licenses for this implementation.
- Runtime source dependency: the MoonBit standard library (`moonbitlang/core`), Apache-2.0. The compiled JS artifact contains compiler-generated code and standard library implementation; see [MoonBit core license](https://github.com/moonbitlang/core/blob/main/LICENSE).
- Build/test tools: MoonBit compiler/core pinned to `0.10.14+7d59c7ec9`, Node.js, Playwright `1.62.1` (Apache-2.0, test-only). Browser runtime uses no third-party UI library, external fonts or network services.
- The LICENSE file is the standard Apache License 2.0 text. The screenshots are captures of this project's running applications.

Application prose supplied as an AI-assisted reference draft must not be represented as human-authored if a submission form prohibits AI-written applications. The entrant should write and verify the final submission themselves.
