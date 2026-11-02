# Implementation status

**Snapshot date: 2026-11-03**

The foundation has been built and tested on the development host. The Phase 0 product milestone is **not complete**: physical Android execution, Kotlin process management, parser integration, LSP transport, and semantic navigation remain unverified or unimplemented.

## Evidence matrix

| Area | State | Evidence |
| --- | --- | --- |
| Flutter Android app | Implemented | Minimal Phase 0 runtime screen in `app/lib/main.dart`; ARM64 APK build passed |
| Flutter ↔ Rust bridge | Implemented, host-tested | FRB 2.13.0 bindings; direct host test covers structured response, async calls, and error propagation |
| Rust native library | ARM64 build/package passed | APK contains `lib/arm64-v8a/libcodexis_core.so`; no physical-device call yet |
| Rust logging | Implemented | `tracing-subscriber` writes to stderr; host test observes log output |
| Kotlin process manager / MethodChannel | Not implemented | Android source remains Flutter's generated `MainActivity` |
| Packaged executable experiment | Not implemented | No probe executable or launch test |
| Content-Length LSP transport | Not implemented | No JSON-RPC transport code |
| Tree-sitter Rust/C/C++/Go | Not implemented | No parser crate or grammar dependencies |
| Git repository storage / index / SQLite | Not implemented | No repository, indexer, or storage crate yet |
| rust-analyzer / clangd / gopls | Not built or tested | No Android server package or language toolchain integration |
| Read-only/local trust enforcement | Product requirements only | No repository workflows or trust UI exist yet |

## Tests that passed

- `cargo test -p codexis-core`: **2 passed**.
- `flutter analyze`: **no issues found**.
- `flutter test`: **2 passed**, including direct host-side Dart-to-Rust calls.
- `flutter build apk --debug --target-platform android-arm64 --no-pub`: **passed**.
- Stable NDK 28.2.13676358 was explicitly passed through the Native Assets hook; the packaged native library reports NDK r28c.

The ARM64 APK was not launched: ADB reported no connected device, and the only installed AVD uses x86_64. Host-side bridge success is not evidence of physical Android execution.

## Milestones

| Milestone | Status |
| --- | --- |
| App and Rust workspace bootstrap | Complete |
| Generated bridge and host calls | Complete |
| Android ARM64 library/APK build | Complete |
| Physical phone Rust load and call | Pending device |
| Native executable and Kotlin process experiments | Not started |
| LSP transport and server feasibility | Not started |
| Tree-sitter and source fixtures | Not started |
| One complete semantic navigation workflow on Android | Not started |

Phase 0 exits only when at least one real semantic-navigation workflow works on physical Android hardware and the remaining language-server paths have an evidence-based feasibility report. The current tree is a foundation, not a working code-intelligence product.

For historical environment detail, see `docs/PHASE_0_STATUS.md` and `docs/PHASE_0.md` in the repository.
