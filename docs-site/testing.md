# Checks and experiments

The project distinguishes host validation, Android packaging, and on-device behavior. Passing one layer does not imply the next.

## Current checks

| Check | Latest recorded outcome |
| --- | --- |
| Rust unit tests | 2 passed in `codexis-core` |
| Flutter analysis | No issues |
| Flutter unit/widget tests | 2 passed |
| Direct Dart → Rust calls | Host test passed structured values, repeated async calls, tracing, and error propagation |
| Android ARM64 Rust library | Built with NDK r28c for Android API 35 through the Flutter Native Assets hook |
| ARM64 debug APK | Built and contains `lib/arm64-v8a/libcodexis_core.so` |
| Physical Android run | Not run; no device attached |
| LSP, parser, repository, executable experiments | Not implemented |

See [the full Phase 0 report](/status) for the environment, command lines, and limitations.

## Minimum test sequence

```bash
cd engine && cargo fmt --all --check && cargo test -p codexis-core
cd ../app && flutter analyze && flutter test
```

Build and inspect the ARM64 package separately:

```bash
cd app
flutter build apk --debug --target-platform android-arm64 --no-pub
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep 'lib/arm64-v8a/libcodexis_core.so'
```

## Future acceptance layers

1. **Android native runtime:** library load/call, executable launch, independent stdout and stderr, exit status, graceful and forced termination, restart, backgrounding, and process death.
2. **Parser:** Rust, C, C++, and Go fixtures; malformed input; normalized declarations and locations; incremental parse.
3. **LSP transport:** `Content-Length` framing measured in UTF-8 bytes, request IDs, response matching, notifications, and shutdown.
4. **Semantic navigation:** real workspace setup, definition and references for each supported server, unresolved symbols, repeat after restart, and offline use.

No result should be marked complete without an executable test or a documented device experiment. The specification's acceptance criteria remain the source of truth for these future checks.
