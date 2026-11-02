import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const runtime = MethodChannel('dev.codexis/runtime');

  testWidgets(
    'launches the APK-embedded ARM64 probe and captures both streams',
    (_) async {
      final result = await runtime.invokeMapMethod<String, Object?>(
        'probeExecutable',
        {'name': 'libcodexis_probe.so'},
      );

      expect(result?['processStarted'], isTrue, reason: '$result');
      expect(result?['probePassed'], isTrue, reason: '$result');
      expect(result?['exitCode'], 23);
      expect(result?['stdout'], contains('CODEXIS_STDOUT_OK'));
      expect(result?['stderr'], contains('CODEXIS_STDERR_OK'));
    },
  );
}
