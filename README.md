# Codexis

Codexis is an Android-first, read-only, local source-code intelligence prototype. Its UI is Flutter, its local engine is Rust, and Android runtime/process experiments live in Kotlin.

## Phase 0 status

See [the environment and compatibility report](docs/PHASE_0_STATUS.md). The first milestone is a verified Flutter-to-Rust call on Android ARM64. Android builds and physical-device claims remain pending until the missing JDK and a reachable Android device are available.

## Development

The Flutter application is in `app/`; Rust workspace code is in `engine/`. See `Codexis_Phase_0_Implementation_Specification.md` for the approved Phase 0 architecture and acceptance criteria.
