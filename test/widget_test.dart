import 'package:flutter_test/flutter_test.dart';

import 'package:vitality_assist/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const VitalityAssistApp());
    await tester.pumpAndSettle();

    expect(find.text('Vitality Assist'), findsOneWidget);
  });
}
