import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/main.dart';
import 'package:hasani_payroll_portal/screens/login_screen.dart';

void main() {
  testWidgets('Application opens the login screen', (tester) async {
    await tester.pumpWidget(const HasaniPayrollApp());

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
