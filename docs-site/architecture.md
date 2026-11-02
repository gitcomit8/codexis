# Architecture

Codexis is specified as an Android-first, read-only, local source-code intelligence application. The product architecture separates the Flutter user interface, Rust analysis/repository engine, and Android runtime responsibilities.

## Implemented foundation

The checked-in code currently has one Rust crate and a small Flutter screen. Flutter's Native Assets hook compiles and packages the Rust library for Android ARM64.

```text
Flutter screen (app/lib/main.dart)
        │ generated typed calls
        ▼
flutter_rust_bridge 2.13.0
        │ FFI / Native Assets
        ▼
codexis-core (engine/crates/codexis-core)
  ├─ RuntimeInfo structured response
  ├─ async greet call with Rust error → Dart exception
  └─ tracing to stderr
```

This flow is exercised on the Linux host by `app/test/rust_bridge_test.dart`. The ARM64 library is present in the debug APK. The Android call has not yet been exercised on physical hardware.

## Intended system boundaries

The following is the approved direction, not a description of completed modules:

| Boundary | Intended responsibility | Current implementation |
| --- | --- | --- |
| Flutter / Dart | Repository browser, code viewer, navigation UI | Minimal runtime probe screen |
| Kotlin Android runtime | Server process lifecycle, stdio streams, LSP JSON-RPC, lifecycle events | Flutter-generated `MainActivity`; no runtime host or process manager |
| Rust engine | Git checkout, Tree-sitter parsing, indexing, SQLite storage | `codexis-core` bridge probe only |
| Language servers | Semantic definitions and references for Rust, C/C++, and Go | None built or packaged |

The architectural separation is purposeful: Kotlin owns Android process APIs and LSP transport in Phase 0; Rust owns repository and indexing logic. The Dart layer receives normalized runtime/navigation results through channels and the Rust bridge.

## Product boundaries

- **Read-only:** repository code can be browsed and analyzed; editing source is outside the product mode.
- **On device:** file access, parsing, indexing, and language-server requests should remain local. Cloud infrastructure is out of scope.
- **Trust modes:** untrusted workspaces allow static parsing and browsing. Full language-server operation requires explicit trust because Cargo build scripts, procedural macros, CMake configuration, and dependency resolution can execute project-controlled code.
- **No implicit builds:** opening a repository must not run its build scripts or automatically download dependencies.
- **Credential isolation:** Git credentials must not be placed in a language-server environment.

These are product and security requirements. Enforcement in the app has not been implemented yet.

## Planned analysis pipeline

```text
Local checkout → file discovery → Tree-sitter syntax index
                                │
                                ├─ static symbols and source locations
                                │
                                └─ trusted workspace → Kotlin LSP session
                                                      → definition / references
```

Tree-sitter will provide structural parsing and local symbols. It is not a semantic compiler and must not be presented as a substitute for rust-analyzer, clangd, or gopls. Semantic navigation depends on each server's toolchain and project metadata: Cargo and Rust tools, a Clang compilation database and headers, or the Go command and module environment.

## Repository map

```text
app/                         Flutter UI, Android project, bridge bindings
  hook/build.dart            Native Assets Rust build hook
  integration_test/          Device-side bridge test source
engine/                      Cargo workspace
  crates/codexis-core/       Current Rust API and generated bridge
docs/                        Phase 0 environment and experiment reports
docs-site/                   This VitePress documentation site
Codexis_Phase_0_Implementation_Specification.md  Approved architecture baseline
```

See [development workflow](/workflow) for the concrete commands and [implementation status](/status) for the acceptance evidence.
