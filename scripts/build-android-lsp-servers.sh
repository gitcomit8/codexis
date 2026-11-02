#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ndk_root="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [[ -z "$ndk_root" || ! -d "$ndk_root/toolchains/llvm/prebuilt/linux-x86_64/bin" ]]; then
  echo "Set ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) to the installed Android NDK." >&2
  exit 2
fi

ndk_bin="$ndk_root/toolchains/llvm/prebuilt/linux-x86_64/bin"
export CC_aarch64_linux_android="$ndk_bin/aarch64-linux-android35-clang"
export CXX_aarch64_linux_android="$ndk_bin/aarch64-linux-android35-clang++"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$CC_aarch64_linux_android"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$repo_root/engine/target/lsp-android}"

install_root="$repo_root/engine/target/lsp-install"
output_dir="$repo_root/app/android/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$output_dir"

cargo +1.98.0 install \
  --path "$repo_root/android-runtime/servers/asm-lsp" \
  --locked --offline --target aarch64-linux-android --root "$install_root"
install -m 0755 "$install_root/bin/asm-lsp" "$output_dir/libasm-lsp.so"

echo "Built and staged APK-embedded Android ARM64 asm-lsp at $output_dir/libasm-lsp.so"
echo "This proves cross-compilation only; verify executable launch on a physical Android device."
