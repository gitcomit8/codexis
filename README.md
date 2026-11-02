# Codexis

Codexis is an Android-first, read-only local code browser and static indexer. Its Flutter interface imports copies of local Git repositories into app-private storage, Rust/Tree-sitter indexes Rust and x86-64 NASM symbols, and Kotlin provides Android storage and process APIs.

## Phase 0 status

The app, local repository workflow, static parser, and ARM64 APK build are implemented. The APK bundles asm-lsp and the Kotlin JSON-RPC host, but neither has been exercised on a physical Android device, and semantic requests are not yet connected to the Flutter UI. Rust-analyzer is not bundled. See [the implementation status](docs-site/status.md) and [the Codexis documentation site](docs-site/).

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
