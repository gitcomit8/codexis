import 'package:codexis/src/rust/api.dart' as rust_api;
import 'package:codexis/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Rust bridge transfers structured data, async calls, and errors',
    () async {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(
          'build/native_assets/linux/libcodexis_core.so',
        ),
      );
      await rust_api.initializeLogging();

      final info = await rust_api.runtimeInfo();
      expect(info.product, 'Codexis');
      expect(info.engine, 'Rust');
      expect(info.version, 1);

      for (var i = 0; i < 5; i++) {
        expect(
          await rust_api.greet(name: 'host $i'),
          'Hello, host $i. Rust is running locally.',
        );
      }
      await expectLater(rust_api.greet(name: '  '), throwsA(isA<Exception>()));

      final symbols = await rust_api.indexRepository(
        root: '../engine/crates/codexis-parser/tests/fixtures',
      );
      expect(
        symbols.any(
          (symbol) =>
              symbol.language == 'rust' &&
              symbol.name == 'helper' &&
              symbol.relativePath == 'rust/lib.rs',
        ),
        isTrue,
      );
      expect(
        symbols.any(
          (symbol) =>
              symbol.language == 'nasm' &&
              symbol.name == '_start' &&
              symbol.relativePath == 'nasm/hello.asm',
        ),
        isTrue,
      );
    },
  );
}
