# Codexis

Codexis is an Android-first, read-only, local source-code intelligence prototype. Its UI is Flutter, its local engine is Rust, and Android runtime/process experiments live in Kotlin.

## Phase 0 status

The Flutter-to-Rust foundation and ARM64 debug APK build are complete and host-tested. Physical-device execution and the parser, LSP, and repository workflows remain unimplemented. See [the implementation status](docs/PHASE_0_STATUS.md) and [the Codexis documentation site](docs-site/).

## Development

The Flutter application is in `app/`; Rust workspace code is in `engine/`. See `Codexis_Phase_0_Implementation_Specification.md` for the approved Phase 0 architecture and acceptance criteria.

## Documentation site

The VitePress site lives in `docs-site/`:

```bash
cd docs-site
npm ci
npm run dev
```

Build the static site with `npm run build` from that directory.
