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
| Rust Android target | `aarch64-linux-android` | Installed in the pinned Rust 1.98.0 toolchain |
| Android SDK | `/home/amb/sdk/Android`, platforms 34–37, build tools 36/37 | Installed; `ANDROID_HOME` is unset |
| Android NDK | 28.2.13676358 (stable) and 30.0.16138531-beta3 | Flutter Gradle and the configured Native Assets hook use stable 28.2 |
| ADB | 37.0.1 at `/home/amb/sdk/Android/platform-tools/adb` | Installed; `adb devices -l` starts successfully and reports no connected devices |
| Java/JDK | JetBrains Runtime 25.0.4 at `/home/amb/.local/share/JetBrains/Toolbox/apps/android-studio/jbr` | `java` is not on PATH; the Android Gradle build succeeded using this JDK |
| CMake | 4.4.5 | Installed |
| Ninja | 1.13.2 | Installed |
| LLVM/Clang | 23.1.4 host compiler | Installed; Android NDK supplies separate target Clang |
| Go | Not installed | `gopls` feasibility/build is blocked |

The Flutter version command initially attempted to update cache metadata under the read-only Flutter SDK path. It completed successfully with the required outside-sandbox command approval. No SDK files were intentionally changed. The JDK was discovered in Android Studio after Gradle started successfully; it is simply absent from the shell PATH. ADB was run outside the sandbox and found no devices.

## Initial compatibility findings

- `flutter_rust_bridge` 2.13.0 requires Dart 3.9 or newer. Installed Dart 3.13.5 meets that requirement; the exact code generator/runtime pair must still be resolved and built from the repository.
- Flutter 3.47.6 generates AGP 9.1.0, Kotlin 2.4.0, and Gradle 9.3.1 project settings. Its Android defaults are compile/target API 36 and NDK 28.2.13676358; the ARM64 APK build passed with the installed JDK 25.
- Rust 1.98.0 is pinned for Native Assets builds. Android ARM64 and Linux host targets are declared; the host target is only used for FFI tests. The Android shared library compiled successfully.
- The Native Assets hook initially selected NDK 30 beta3 because it was the newest installed SDK package. The build hook now accepts `ANDROID_NDK_HOME` (or `ANDROID_NDK_ROOT`) and explicitly overrides the ARM64 compiler and linker paths. Rebuilding with stable NDK 28.2.13676358 succeeded and the packaged Rust library reports NDK r28c. Set one of those variables to the intended NDK to keep the choice reproducible.
- Android 10+ disallows `execve()` of app-controlled executable files in the writable app home directory for apps targeting API 29+. The documented Android-supported route is code embedded in the APK. This makes native-library loading a viable experiment, but does not establish that an independently packaged language-server executable can be launched. The exact packaged artifact and on-device behavior remain untested.
- No physical device is attached, so there is no hardware ABI or API level to report.
- Rust, C/C++, and Go language-server execution is not established. In particular, a server's ARM64 binary alone would not supply the Cargo/Rust, Clang/header, or Go toolchain capabilities identified in the specification.

## Dependency validation status

The specification's Flutter/Rust versions are candidates, not yet resolved dependencies. Flutter/Dart compatibility for `flutter_rust_bridge` 2.13.0 is verified from package metadata. The remaining Rust crate versions, Tree-sitter grammar ABI compatibility, native libgit2/SQLite Android builds, code generation, and dependency lockfiles require repository builds and tests before being called compatible.

## Current blockers and next evidence

1. Connect a physical ARM64 Android device so the packaged Rust library and executable experiment can be tested on-device. The only installed AVD is x86_64 and cannot run this ARM64-only APK.
2. Install Go before attempting `gopls` and its Go-toolchain-dependent workspace behavior.

The ARM64 APK and native library builds have passed, as have Flutter analysis, Flutter unit tests, and direct host-side Dart-to-Rust calls. No physical Android execution, arbitrary executable launch, or semantic-navigation test has passed as of this report. See [the Phase 0 execution report](PHASE_0.md) for results and limitations.
