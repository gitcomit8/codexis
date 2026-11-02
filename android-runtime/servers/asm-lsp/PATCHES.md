# Codexis asm-lsp build

This is the `asm-lsp` 0.10.1 crates.io source with a small Android/offline patch.
The manifest and lockfile are pinned and the Android build script compiles this
source for `aarch64-linux-android` with the NDK.

- Removed the `reqwest` dependency. Upstream fetches x86 instruction reference
  HTML when no cache is present; Codexis never performs network requests. The
  server reads optional documentation only from its app-private cache.
- The crates.io source archive omits upstream `docs_store` test fixtures. Its
  fixture-dependent upstream test module is excluded; a local test verifies
  missing instruction documentation remains optional and does not trigger a
  request. Codexis separately tests NASM parsing and symbol locations using a
  real Tree-sitter NASM grammar fixture.

The server's own code supports NASM assembly syntax. Cross-compilation does not
prove that Android permits the embedded executable to launch; that still needs
the packaged probe and server to be exercised on physical ARM64 hardware.
