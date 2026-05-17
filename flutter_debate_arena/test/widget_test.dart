import 'package:logic_bout/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows auth or home after session load', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LogicBoutApp());
    await tester.pumpAndSettle();
    expect(find.text('Logic Bout'), findsOneWidget);
  });
}
