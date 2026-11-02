# Phase 0 environment and compatibility report

**Inspection date:** 2026-11-03  
**Repository state:** Empty Git repository on `main`; the approved specification is present as an untracked input file. No implementation files existed at inspection time.

## Environment

| Component | Observed | Status |
|---|---|---|
| Host | CachyOS Linux, x86_64 | Suitable host architecture |
| Flutter | 3.47.6 stable | Installed; `flutter --version` succeeded when run outside the restricted SDK-cache sandbox |
| Dart | 3.13.5 stable | Installed |
| Rust/Cargo | 1.98.0 stable | Installed |
| Rust Android target | `aarch64-linux-android` recognized by rustc, not installed in rustup | Can be installed if registry/network access permits |
| Android SDK | `/home/amb/sdk/Android`, platforms 34–37, build tools 36/37 | Installed; `ANDROID_HOME` is unset |
| Android NDK | 28.2.13676358 and 30.0.16138531 | Installed; NDK 30 has the expected Linux LLVM toolchain |
| ADB | 37.0.1 at `/home/amb/sdk/Android/platform-tools/adb` | Installed; the sandbox prevented its server from opening its local socket, so connected devices could not yet be enumerated |
| Java/JDK | `java` and `javac` not on PATH; no candidate found under `/home/amb/sdk` or `/usr/lib/jvm` | Missing; Gradle/Android builds are blocked until a JDK is made available |
| CMake | 4.4.5 | Installed |
| Ninja | 1.13.2 | Installed |
| LLVM/Clang | 23.1.4 host compiler | Installed; Android NDK supplies separate target Clang |
| Go | Not installed | `gopls` feasibility/build is blocked |

The Flutter version command initially attempted to update cache metadata under the read-only Flutter SDK path. It completed successfully with the required outside-sandbox command approval. No SDK files were intentionally changed. Device enumeration similarly needs an ADB server socket, which the sandbox currently denies.

## Initial compatibility findings

- `flutter_rust_bridge` 2.13.0 requires Dart 3.9 or newer. Installed Dart 3.13.5 meets that requirement; the exact code generator/runtime pair must still be resolved and built from the repository.
- Flutter 3.47.6 and Android platforms through API 37 are available. The Flutter Android build cannot yet be validated because no Java runtime is installed.
- The Rust toolchain recognizes the ARM64 Android target, but only the x86_64 host target is installed. No Rust Android cross-build has passed yet.
- Android NDK 28 and 30 are present. The AGP version and NDK pairing will be established from the generated Flutter project before selecting one; no NDK version will be hardcoded based on presence alone.
- Android 10+ disallows `execve()` of app-controlled executable files in the writable app home directory for apps targeting API 29+. The documented Android-supported route is code embedded in the APK. This makes native-library loading a viable experiment, but does not establish that an independently packaged language-server executable can be launched. The exact packaged artifact and on-device behavior remain untested.
- No physical device result is available. The sandbox blocked ADB daemon startup; there is no evidence yet about connected hardware, ABI, or API level.
- Rust, C/C++, and Go language-server execution is not established. In particular, a server's ARM64 binary alone would not supply the Cargo/Rust, Clang/header, or Go toolchain capabilities identified in the specification.

## Dependency validation status

The specification's Flutter/Rust versions are candidates, not yet resolved dependencies. Flutter/Dart compatibility for `flutter_rust_bridge` 2.13.0 is verified from package metadata. The remaining Rust crate versions, Tree-sitter grammar ABI compatibility, native libgit2/SQLite Android builds, code generation, and dependency lockfiles require repository builds and tests before being called compatible.

## Current blockers and next evidence

1. Provide a usable JDK (or allow installation) to build the Android app.
2. Permit ADB server access or provide a device connection so ABI/API and physical runtime behavior can be tested.
3. Install the ARM64 Rust target and resolve Cargo/Pub dependencies; network availability has not been established.
4. Install Go before attempting `gopls` and its Go-toolchain-dependent workspace behavior.

No Android build, device test, executable launch, or semantic-navigation test has passed as of this report. This file will be updated with measured results as experiments are completed.
