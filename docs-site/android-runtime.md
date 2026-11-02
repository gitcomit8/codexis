# Android runtime feasibility

Loading a Rust shared library and launching an independent language server are separate Android capabilities.

## Implemented and verified

- The ARM64 APK packages `libcodexis_core.so`, `libasm-lsp.so`, and a debug-only native process probe.
- Kotlin has code for SAF repository copying, stdio process management, separate stdout/stderr capture, request IDs, Content-Length framing, stop/restart state, and JSON-RPC request/notification transport.
- The probe writes markers to both streams and exits with status 23. An Android integration test asserts those details.
- The Kotlin frame codec has unit tests for UTF-8 byte lengths, partial reads, malformed frames, and truncated bodies.

## Not verified on device

There is no connected physical ARM64 device in the development environment. APK packaging does not prove that `ProcessBuilder` can launch the native-library payload. Therefore executable launch, process restart/backgrounding, probe integration assertions, and the Android LSP runtime remain device-unverified.

Android 10 and later restrict execution of app-controlled binaries in writable app-home directories for apps targeting API 29+. Codexis tests the APK-embedded `nativeLibraryDir` strategy and does not extract binaries into writable storage. See the [Android behavior change documentation](https://developer.android.com/about/versions/10/behavior-changes-10#execute-permission).

## Server evidence

The vendored asm-lsp 0.10.1 source builds for `aarch64-linux-android`; an offline patch removes its runtime HTTP documentation fetch. A host-side JSON-RPC test initializes the server and resolves NASM definitions/references within one file. Cross-file navigation is not established by that server workflow. Rust-analyzer is not bundled because a matching Android server plus `rustc`, Cargo, and offline dependency metadata have not been delivered.

Do not describe semantic navigation as supported until the app invokes requests and the complete flow succeeds on physical Android hardware. The app currently exposes Tree-sitter symbols as static syntax results.
