import 'package:flutter_test/flutter_test.dart';
import 'package:screenscrab_android/main.dart';

void main() {
  testWidgets('builds the Android shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ScreenscrabAndroidApp());

    expect(find.text('Screenscrab Android'), findsOneWidget);
    expect(find.text('Client status'), findsOneWidget);
  });
}
