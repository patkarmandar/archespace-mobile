import 'package:flutter_test/flutter_test.dart';
import 'package:archespace_mobile/main.dart';

void main() {
  testWidgets('app shell renders', (tester) async {
    await tester.pumpWidget(const ArcheApp());
    expect(find.text('Arche Space'), findsOneWidget);
  });
}
