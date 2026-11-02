# Vendored Tree-sitter NASM grammar

This crate contains the generated C parser from
[`naclsn/tree-sitter-nasm`](https://github.com/naclsn/tree-sitter-nasm),
revision `d1b3638d017f2a8585e26dcfc66fe1df94185e30`, under its MIT license.

The upstream Rust binding depends on the Tree-sitter 0.20 runtime. Codexis
compiles the upstream generated parser C and exposes it through the stable
`tree-sitter-language` `LanguageFn` interface instead, allowing the grammar to
be used with the workspace's Tree-sitter 0.27 runtime without linking a second,
older runtime. The upstream parser reports ABI 14; Tree-sitter 0.27 accepts it.

The generated parser is intentionally checked in so Android builds do not need
the Tree-sitter CLI or Node.js. To update it, regenerate `src/parser.c` from the
upstream grammar and update the recorded revision after running NASM fixture
tests on host and Android ARM64.
