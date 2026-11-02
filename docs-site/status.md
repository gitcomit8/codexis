# Implementation status

**Snapshot date: 2026-11-03**

Codexis now has a usable Android application foundation for importing a local Git checkout, browsing Rust/NASM files, and building a local static symbol index. The release is **not yet feature-complete**: Android runtime execution has not been verified on a physical device, semantic LSP requests are not wired into the Flutter interface, and no Rust language server is packaged.

## Evidence matrix

| Area | State | Evidence and limits |
| --- | --- | --- |
| Flutter Android application | Implemented | Local workspace list, import/remove, read-only file browser, source viewer, static symbols |
| Flutter ↔ Rust bridge | Implemented | FRB 2.13.0; host tests exercise structured calls and repository indexing |
| Rust/NASM parser | Implemented | Tree-sitter parser and repository scanner with source locations; six parser tests pass |
| SAF import and repository storage | Implemented in Kotlin | Selected Git directory is copied into app-private storage; original remains untouched |
| Kotlin process manager and JSON-RPC framing | Implemented, device-unverified | Content-Length framing, UTF-8 lengths, request IDs, separate stdout/stderr and process lifecycle |
| NASM language server | ARM64 cross-built and packaged | asm-lsp 0.10.1; host test proves initialize, same-file definition and references; APK includes executable |
| Rust semantic server | Not packaged | rust-analyzer needs a compatible Android build and Rust toolchain/Cargo metadata; feasibility remains unresolved |
| Cross-file NASM navigation | Unsupported by tested server workflow | Current asm-lsp implementation resolves definitions/references in the open file only |
| Android native executable launch | Not verified | Debug APK packages a probe and asm-lsp; ADB reports no connected device |
| Full semantic workflow in the UI | Not implemented | The app labels Tree-sitter results as static symbols, not LSP results |

## Checks run

- `cargo fmt --all` and `cargo test -p codexis-parser -p codexis-core`: passed (8 tests).
- Flutter analyzer: passed with no issues.
- `flutter analyze`: passed with no issues; `flutter test`: all 8 tests passed.
- `:app:testDebugUnitTest`: passed, including Kotlin JSON-RPC framing cases.
- `npm run build` in `docs-site`: passed.
- ARM64 debug APK: built successfully and inspected; contains `lib/arm64-v8a/libcodexis_core.so`, `libasm-lsp.so`, and `libcodexis_probe.so`.
- ARM64 release APK: built and APK signature verified; includes the Rust core and asm-lsp, and omits the debug-only probe.
- asm-lsp host JSON-RPC integration: passed initialize, same-file definition, and references (3 locations).
- Android unit tests and physical-device executable launch: not yet verified.

The release APK is a sideloadable engineering build signed with the local debug key. It is not a Play Store release. The app is useful for local browsing and static indexing, but semantic navigation must not be represented as supported until both the UI workflow and Android runtime have been exercised on hardware.
