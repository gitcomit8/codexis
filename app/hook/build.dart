import 'dart:io';

import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  final ndkHome =
      Platform.environment['ANDROID_NDK_HOME'] ??
      Platform.environment['ANDROID_NDK_ROOT'];
  await build(args, (input, output) async {
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: '../engine/crates/codexis-core',
      extraCargoEnvironmentVariables: ndkHome == null
          ? const <String, String>{}
          : _androidNdkEnvironment(ndkHome),
    ).run(input: input, output: output);
  });
}

Map<String, String> _androidNdkEnvironment(String ndkHome) {
  final bin = '$ndkHome/toolchains/llvm/prebuilt/linux-x86_64/bin';
  final sysroot = '$ndkHome/toolchains/llvm/prebuilt/linux-x86_64/sysroot';
  const targetEnv = 'aarch64_linux_android';
  const linker = 'aarch64-linux-android35-clang';
  return {
    'AR_$targetEnv': '$bin/llvm-ar',
    'CC_$targetEnv': '$bin/$linker',
    'CXX_$targetEnv': '$bin/aarch64-linux-android35-clang++',
    'RANLIB_$targetEnv': '$bin/llvm-ranlib',
    'CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER': '$bin/$linker',
    'BINDGEN_EXTRA_CLANG_ARGS_$targetEnv':
        '--sysroot=$sysroot -I$sysroot/usr/include/aarch64-linux-android',
  };
}
