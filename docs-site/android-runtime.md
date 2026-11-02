# Android runtime feasibility

Android library loading and launching an independent executable are different experiments. A successful Rust shared-library build does not imply that `ProcessBuilder` can launch an arbitrary server binary.

## What is verified

- Flutter packages `libcodexis_core.so` into the ARM64 APK.
- The shared library builds with the stable NDK 28.2.13676358 selected through `ANDROID_NDK_HOME`.
- The APK build succeeds on the development host.
- The generated Flutter `MainActivity` exists, but no Kotlin process host, LSP transport, or executable probe is currently implemented.

## What is not verified

- Loading and calling the packaged library on a physical Android phone.
- Starting a separately packaged PIE executable from `nativeLibraryDir`.
- stdout/stderr capture, graceful shutdown, forced termination, or restart.
- Background/foreground recovery or process-kill recovery.
- Any language server on Android.

The environment had no attached device. Its only configured AVD is x86_64, while this prototype builds ARM64 only, so that emulator cannot exercise the APK.

## Executable restriction

Android 10 and later disallow apps targeting API 29 or higher from calling `execve()` on app-controlled binaries located in the app's writable home directory. Android recommends loading executable code embedded in the APK. See the [Android 10 behavior changes](https://developer.android.com/about/versions/10/behavior-changes-10#execute-permission).

This rule is why a downloaded server in `filesDir/bin` cannot be assumed to work. The approved experiment is to package a small Android ARM64 PIE executable as a native artifact and attempt to launch it from the installed `nativeLibraryDir` on a real device. If that fails, investigate the documented alternatives: a shared library with a JNI entry point, an in-process server, or a purpose-built runtime host. Record the exact OS error and Android version; do not silently switch the server's execution model.

## Language-server prerequisites

| Server | Additional runtime inputs identified in the specification |
| --- | --- |
| rust-analyzer | Rust toolchain, `rustc`, Cargo metadata, workspace dependencies |
| clangd | `compile_commands.json`, compiler configuration, project headers |
| gopls | Go command, Go environment, module/workspace metadata |

Each server needs an Android-compatible build and a working semantic test. A binary that starts or returns from `initialize` is insufficient; the acceptance flow must resolve a definition and references in a real project.
