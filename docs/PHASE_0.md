# Phase 0 execution report

**Date:** 2026-11-03  
**Scope completed:** P0-A Flutter/Rust foundation, host-side bridge verification, and ARM64 APK packaging.  
**Overall Phase 0:** In progress. Android on-device runtime and semantic LSP objectives have not been demonstrated.

## Implemented

- Flutter Android app with a minimal local runtime screen.
- Rust workspace and `codexis-core` crate.
- `flutter_rust_bridge` 2.13.0 code generation and Dart API.
- Structured `RuntimeInfo`, async Rust call, `anyhow` error propagation, and stderr tracing initialization.
- Flutter Native Assets build hook, pinned Rust 1.98.0 toolchain, Android ARM64 and Linux host test targets, and an explicit stable NDK override through `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT`.
- Android minimum API 29 and ARM64-only APK build.
- Host-side direct bridge test and device-side integration test source.

## Experiment results

| Experiment | Result | Evidence / limitation |
|---|---|---|
| Flutter/Dart dependency resolution | PASS | `flutter pub get`; bridge 2.13.0 resolved with Flutter 3.47.6 and Dart 3.13.5 |
| Bridge code generation | PASS | Pinned codegen 2.13.0 generated checked-in Dart and Rust bindings |
| Rust unit tests | PASS | `cargo test -p codexis-core`: 2 passed |
| Flutter analysis and widget tests | PASS | `flutter analyze`: no issues; `flutter test`: 2 passed |
| Actual Dart-to-Rust calls | PASS on Linux host | Direct test verifies structured values, five async calls, tracing, and Dart exception propagation |
| Rust Android ARM64 compilation | PASS | `libcodexis_core.so` is ELF64 AArch64 for Android API 29; Cargo release build succeeded |
| Flutter ARM64 APK build | PASS | `flutter build apk --debug --target-platform android-arm64`; APK includes `lib/arm64-v8a/libcodexis_core.so` |
| Device Rust library load/call | NOT RUN | ADB reports no connected device; host tests do not substitute for Android execution |
| Rust library restart/background lifecycle | NOT RUN | Requires on-device runtime testing |
| Packaged executable launch | NOT IMPLEMENTED | P0-B remains next |
| LSP transport or semantic navigation | NOT IMPLEMENTED | No server process or LSP workflow is claimed |

## Toolchain compatibility and deviations

- Flutter 3.47.6 defaults to compile SDK 36, target SDK 36, and NDK 28.2.13676358. The generated project selected AGP 9.1.0, Kotlin 2.4.0, and Gradle 9.3.1. It built with the available JetBrains Runtime 25.0.4.
- The Flutter Native Assets hook initially selected NDK 30.0.16138531-beta3 because it was the newest installed SDK package. The hook now accepts `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` and passes explicit NDK compiler/linker paths; an ARM64 APK rebuild with stable NDK 28.2.13676358 passed. The resulting `.so` reports NDK r28c. Set the variable explicitly in reproducible build commands.
- The Linux host target is declared to run FFI tests on the development machine. No Android x86 emulator ABI has been added.
- The app has `minSdk = 29`. Its target SDK follows the current Flutter default (36) rather than pinning an older SDK.
- Native Assets builds the Rust shared library as APK native code. It does not prove that an independent executable can run from app storage or `nativeLibraryDir`.

## Next work

1. Add the Kotlin process host, Content-Length LSP framing, and packaged PIE executable probe.
2. Test executable launch, stdio, termination, and restart on a physical Android device when one is available. Do not infer device behavior from host tests.
3. Add Tree-sitter grammars and real parser fixtures after runtime experiments.
4. Attempt language-server builds and workspaces in Rust, C/C++, then Go; report unsupported toolchain dependencies honestly.
