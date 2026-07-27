import 'package:flutter_test/flutter_test.dart';
import 'package:screenscrab_windows/main.dart';

void main() {
  testWidgets('builds the Windows shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ScreenscrabWindowsApp(enableDiagnostics: false));

    expect(find.text('Screenscrab Windows'), findsOneWidget);
    expect(find.text('Session Dashboard'), findsOneWidget);
  });
}
