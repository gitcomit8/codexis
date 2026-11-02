#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ndk_root="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [[ -z "$ndk_root" || ! -d "$ndk_root/toolchains/llvm/prebuilt/linux-x86_64/bin" ]]; then
  echo "Set ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) to the installed Android NDK." >&2
  exit 2
fi

compiler="$ndk_root/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang"
output="$repo_root/app/android/app/src/debug/jniLibs/arm64-v8a/libcodexis_probe.so"
mkdir -p "$(dirname "$output")"
"$compiler" -O2 -fPIE -pie "$repo_root/app/android/app/src/main/cpp/codexis_probe.c" -o "$output"
echo "Built Android ARM64 PIE probe: $output"
