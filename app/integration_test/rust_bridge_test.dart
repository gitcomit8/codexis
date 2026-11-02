import 'package:codexis/src/rust/api.dart' as rust_api;
import 'package:codexis/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Rust bridge serializes, runs async calls, and returns errors', (
    tester,
  ) async {
    await RustLib.init();
    await rust_api.initializeLogging();

    final info = await rust_api.runtimeInfo();
    expect(info.product, 'Codexis');
    expect(info.engine, 'Rust');
    expect(info.version, 1);

    for (var i = 0; i < 5; i++) {
      expect(
        await rust_api.greet(name: 'device $i'),
        'Hello, device $i. Rust is running locally.',
      );
    }
    await expectLater(rust_api.greet(name: '  '), throwsA(isA<Exception>()));
  });
}
