---
layout: home
title: Codexis — Field guide
titleTemplate: false
description: Architecture and implementation notes for the Android-first, local source-code intelligence app.
hero:
  name: Codexis
  text: Read a codebase. Keep it on device.
  tagline: "An engineering field guide to the architecture, setup, trust boundaries, and verified capabilities of Codexis."
  actions:
    - theme: brand
      text: Read the architecture
      link: /architecture
    - theme: alt
      text: See what works today
      link: /status
features:
  - title: Local by design
    details: Import a local Git folder into app-private storage; browsing and analysis work against that copy.
    link: /architecture#product-boundaries
    linkText: Product boundaries
  - title: Native analysis
    details: Flutter calls a Rust Tree-sitter index through generated flutter_rust_bridge bindings; Kotlin handles Android storage and process APIs.
    link: /architecture#implemented-system
    linkText: Implemented system
  - title: Evidence before promises
    details: Static symbols, host-tested asm-lsp behavior, and Android-unverified runtime paths are reported separately.
    link: /status
    linkText: Implementation status
---

## The current system

<div class="codex-flow" aria-label="Current Codexis architecture">
  <div><span>01 · App</span><strong>Flutter / Kotlin</strong><p>Import local repositories and browse source read-only.</p></div>
  <div><span>02 · Index</span><strong>Rust + Tree-sitter</strong><p>Build Rust and NASM static symbol locations locally.</p></div>
  <div><span>03 · Runtime</span><strong>Android ARM64</strong><p>Packages asm-lsp and a launch probe; device execution remains unverified.</p></div>
</div>

The app supports local repository copies, source browsing, and Tree-sitter static indexing. These are not semantic code navigation. The Android process host is implemented, but the packaged binaries have not been tested on a phone, and Rust-analyzer is not bundled. See [the status matrix](/status) for exact evidence.

## Read by task

| If you want to… | Start here |
| --- | --- |
| Understand what works and what remains | [Implementation status](/status) |
| Understand the app layers and boundaries | [Architecture](/architecture) |
| Configure Flutter, Rust, Android SDK, and NDK | [Environment and setup](/setup) |
| Regenerate the bridge and run checks | [Development workflow](/workflow) |
| Understand Android executable restrictions | [Android runtime feasibility](/android-runtime) |

<div class="codex-status-grid">
  <div class="codex-status-card"><strong>Built</strong><p>Flutter app, Rust bridge/parser, Kotlin repository/runtime host, ARM64 APK with asm-lsp.</p></div>
  <div class="codex-status-card"><strong>Verified on host</strong><p>Rust parser tests, Flutter tests, bridge indexing, and asm-lsp same-file definitions/references.</p></div>
  <div class="codex-status-card"><strong>Not yet proven</strong><p>Physical-device executable launch, Rust semantic support, and end-to-end LSP from the app UI.</p></div>
</div>

Implementation snapshot dated **2026-11-03**. The site describes checked-in source and measured results; it does not imply unsupported semantic features are complete.
