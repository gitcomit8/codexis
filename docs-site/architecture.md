# Architecture

Codexis is an Android-first, local, read-only source browser and code indexer. The current implementation is split across Flutter/Dart, Kotlin Android APIs, and Rust.

## Implemented system

```text
Flutter UI (app/lib/main.dart)
  ├─ repository/file browsing ── MethodChannel ── Kotlin RepositoryStore
  └─ static symbol index ─────── flutter_rust_bridge ── Rust codexis-parser
                                                           └─ Tree-sitter Rust + NASM

Kotlin RuntimeProcessManager
  └─ stdio JSON-RPC framing ── APK nativeLibraryDir ── asm-lsp (ARM64)
```

The Android repository store imports a SAF-selected local Git directory into app-private storage. The original directory is never edited. Dart exposes repository navigation and a read-only viewer; Rust scans supported files and returns normalized symbol locations. Tree-sitter is syntax-only and its results are explicitly labelled static symbols.

The Kotlin runtime layer has process lifecycle and JSON-RPC transport code. It packages an ARM64 asm-lsp binary and has a native executable probe. Neither executable has been launched on a physical Android device, and no Flutter screen currently invokes semantic LSP requests.

## Responsibilities

| Layer | Implemented responsibility |
| --- | --- |
| Flutter / Dart | Repository list, folder import, read-only browsing, source view, static symbol filtering/navigation |
| Kotlin Android | SAF import/copy, private repository storage, process host, stdout/stderr events, JSON-RPC framing |
| Rust | FRB API, Tree-sitter Rust/NASM parser, read-only repository index |
| asm-lsp | ARM64 packaged binary; host-tested for NASM same-file definitions/references |

Rust semantic navigation is not available: rust-analyzer and the accompanying Cargo/rustc toolchain are not packaged. The tested asm-lsp workflow does not provide cross-file navigation. See [implementation status](/status) for evidence and limits.

## Product boundaries

- **Read-only:** Codexis imports a copy and exposes no source editing or write-back operation.
- **Local operation:** source import, parsing, indexing, and runtime communication are designed to stay on device. The asm-lsp source is patched to avoid runtime network fetches.
- **No implicit workspace builds:** opening a repository does not run Cargo build scripts or resolve dependencies.
- **Trust:** repository build scripts and procedural macros can execute code. Current static browsing does not run them; a Rust LSP implementation will need explicit trust and offline dependency policy before activation.

## Repository map

```text
app/                         Flutter UI and Android app
  lib/                       UI and MethodChannel/FRB clients
  android/app/src/main/      Kotlin host and native-library packaging
engine/crates/codexis-core/  FRB API
engine/crates/codexis-parser/ Tree-sitter Rust/NASM indexer
android-runtime/servers/     Patched asm-lsp source
scripts/                     Android server/probe builds and host LSP check
docs-site/                   VitePress documentation
```

See [setup](/setup), [development workflow](/workflow), and [status](/status).
