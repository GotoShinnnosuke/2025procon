// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:fitness/main.dart';

void main() {
  testWidgets('App shows auth landing when logged out', (tester) async {
    await tester.pumpWidget(const FitnessApp());
    await tester.pumpAndSettle();

    // Auth landing should be visible by default
    expect(find.text('アカウント'), findsOneWidget);
    expect(find.text('ユーザー登録を開始'), findsOneWidget);
  });
}
