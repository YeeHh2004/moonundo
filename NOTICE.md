# Originality, references and tooling

MoonUndo is an original, AI-assisted implementation under Apache-2.0. It is not a line-by-line translation or port of Redux, Loro, event-graph-walker, or another undo library. These projects' source code has not been incorporated.

- Conceptual reference: [Redux – Implementing Undo History](https://redux.js.org/usage/implementing-undo-history), describing general undoable state. No code copied.
- Ecosystem comparison only: projects linked in [SELECTION.md](docs/SELECTION.md). Their licenses are not represented as licenses for this implementation.
- Runtime source dependency: the MoonBit standard library (`moonbitlang/core`), primarily Apache-2.0, with additional upstream notices for adapted components. The compiled JS artifact contains compiler-generated code and standard library implementation. The pinned distribution's full [LICENSE](licenses/MoonBit-core-LICENSE) and [NOTICE](licenses/MoonBit-core-NOTICE) are preserved, including Go, V8/fdlibm, musl/Arm and FreeBSD attributions. Full notices are retained even where a particular build may not link every component.
- Build/test tools: MoonBit compiler/core pinned to `0.10.14+7d59c7ec9`, Node.js, Playwright `1.62.1` (Apache-2.0, test-only). Browser runtime uses no third-party UI library, external fonts or network services.
- The LICENSE file is the standard Apache License 2.0 text. The screenshots are captures of this project's running applications.
- Copyright 2026 YeeHh2004 and MoonUndo contributors for original project code. Builds copy the project license and full upstream notices into the publicly served web directory and release archives. `web/build-info.json` identifies the source commit, version, dirty status, toolchain and compiled engine SHA-256.

Application prose supplied as an AI-assisted reference draft must not be represented as human-authored if a submission form prohibits AI-written applications. The entrant should write and verify the final submission themselves.
