# Environment and setup

These instructions match the current repository layout. The Android minimum SDK is 29; Flutter/Gradle compiles against the installed API level (36 in the recorded environment).

## Required tools

| Tool | Used for | Current tested environment |
| --- | --- | --- |
| Flutter / Dart | App, code generation orchestration, checks | Flutter 3.47.6 / Dart 3.13.5 |
| Rust / Cargo | Native engine and bridge | Rust 1.98.0, pinned in the core crate |
| Android SDK | Gradle and APK packaging | API 36 compile/target |
| Android NDK | Rust Android compilation | Stable 28.2.13676358 |
| JDK | Gradle | JDK 17+; tested here with JetBrains Runtime 25.0.4 |
| Node.js / npm | Documentation site | Node 24.21.0 / npm 11.19.0 in the authoring environment |

Go, LLVM/Clang host tools, CMake, Ninja, and ADB are only needed for later language-server or native runtime experiments. No physical Android device was connected during the recorded build.

## Configure Android paths

Set these for your SDK installation. Point `ANDROID_NDK_HOME` at the stable NDK version selected by your Flutter/AGP toolchain; the Native Assets hook uses its compiler paths explicitly.

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
```

The pinned Rust toolchain includes `aarch64-linux-android` and `x86_64-unknown-linux-gnu` (for host bridge tests). Codexis packages Android ARM64 only. The NASM server build also requires Rust 1.98.0, NDK 28.2.13676358, and all locked crates already cached locally; it uses Cargo offline mode and makes no dependency downloads.

## Resolve app dependencies

```bash
cd app
flutter pub get
```

`app/pubspec.lock` and `engine/Cargo.lock` are checked in. Keep the Flutter bridge package, Rust crate, and code generator on the same exact `flutter_rust_bridge` version.

## Build the ARM64 APK

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"

cd app
flutter build apk --debug --target-platform android-arm64 --no-pub
```

Output: `app/build/app/outputs/flutter-apk/app-debug.apk`.

To package the NASM language server, build it before Gradle:

```bash
./scripts/build-android-lsp-servers.sh
```

The script stages `libasm-lsp.so` in Android's native library directory. For the debug-only process experiment, also run `./scripts/build-android-probe.sh`; the probe is not included in release variants. A server build is cross-compilation evidence only. Rust-analyzer is not currently bundled.

## Install on a connected device

```bash
adb devices -l
adb install -r app/build/app/outputs/flutter-apk/app-debug.apk
```

The current codebase needs a physical ARM64 device test before native executable launch or server use can be called verified on Android. The recorded host tests do not replace that step. The release APK is currently signed using the Gradle debug signing key for sideloading; it is not signed for Play Store distribution.
