import 'package:flutter_test/flutter_test.dart';
import 'package:bastasaving/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BastaSavingApp());
    expect(find.text('BastaSaving'), findsOneWidget);
  });
}
