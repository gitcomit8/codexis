import 'package:codexis/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Codexis runtime screen', (tester) async {
    await tester.pumpWidget(const CodexisApp());

    expect(find.text('Codexis'), findsOneWidget);
  });
}
