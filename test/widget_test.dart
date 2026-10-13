import 'package:flutter_test/flutter_test.dart';
import 'package:darvoza/main.dart';

void main() {
  testWidgets('Darvoza basic UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DarvozaApp());
    expect(find.text('DARVOZA'), findsOneWidget);
    expect(find.text('Himoya faol'), findsOneWidget);
  });
}
