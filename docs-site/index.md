---
layout: home
title: Codexis — Field guide
titleTemplate: false
description: Architecture and implementation notes for an Android-first, local source-code intelligence app.
hero:
  name: Codexis
  text: Read a codebase. Keep it on device.
  tagline: "An engineering field guide to the Android-first source intelligence prototype: its architecture, setup, trust boundaries, and what the current code can actually do."
  actions:
    - theme: brand
      text: Read the architecture
      link: /architecture
    - theme: alt
      text: See what works today
      link: /status
features:
  - title: Local by design
    details: Source and analysis are intended to stay on the device. No cloud index or remote analysis service is part of the architecture.
    link: /architecture#product-boundaries
    linkText: Product boundaries
  - title: Native core, small bridge
    details: Flutter calls a Rust core through generated flutter_rust_bridge bindings; Android packaging uses Flutter Native Assets.
    link: /architecture#implemented-foundation
    linkText: Implemented foundation
  - title: Evidence before promises
    details: The status guide distinguishes tested foundation work from the still-unbuilt parser, runtime host, and language-server workflows.
    link: /status
    linkText: Implementation status
---

## The current system

<div class="codex-flow" aria-label="Current Flutter to Rust call path">
  <div><span>01 · UI</span><strong>Flutter / Dart</strong><p>Android screen and user interaction.</p></div>
  <div><span>02 · Bridge</span><strong>flutter_rust_bridge</strong><p>Generated, typed calls and structured values.</p></div>
  <div><span>03 · Core</span><strong>Rust library</strong><p>Runtime probe, async call, and tracing today.</p></div>
</div>

The app currently demonstrates the bridge and builds an ARM64 APK. That is a foundation check, not semantic code navigation. The Kotlin LSP process host, Tree-sitter parsers, repository storage, and language servers remain future implementation work. See [the status matrix](/status) for exact evidence.

## Read by task

| If you want to… | Start here |
| --- | --- |
| Understand what is running and what is only planned | [Implementation status](/status) |
| Follow the intended modules and data boundaries | [Architecture](/architecture) |
| Set up Flutter, Rust, Android SDK, and NDK | [Environment and setup](/setup) |
| Regenerate the bridge and run local checks | [Development workflow](/workflow) |
| Understand Android executable restrictions | [Android runtime feasibility](/android-runtime) |

## Current evidence

<div class="codex-status-grid">
  <div class="codex-status-card"><strong>Built</strong><p>Flutter app, generated Rust bridge, Android ARM64 native library, debug APK.</p></div>
  <div class="codex-status-card"><strong>Verified on host</strong><p>Rust unit tests, Flutter analysis and widget tests, direct Dart-to-Rust calls.</p></div>
  <div class="codex-status-card"><strong>Not yet proven</strong><p>Physical-device startup, Kotlin process management, LSP, parsing, definition and reference navigation.</p></div>
</div>

Implementation snapshot dated **2026-11-03**. The site describes the checked-in source and recorded test results; it does not imply that the unimplemented product milestones are complete.
