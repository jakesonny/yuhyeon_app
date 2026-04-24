// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app.dart';

void main() {
  testWidgets('로그인 버튼이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: YuhyunMobileApp()));
    await tester.pump();
    expect(find.text('로그인'), findsOneWidget);
  });
}
