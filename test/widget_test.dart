import 'package:flutter_test/flutter_test.dart';
import 'package:ttlock_ops/main.dart';

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const TtlockOpsApp());
    await tester.pump();
    expect(find.text('TTLock Ops'), findsOneWidget);
  });
}
