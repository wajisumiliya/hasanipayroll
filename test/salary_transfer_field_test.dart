import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/salary_transfer_field.dart';

void main() {
  testWidgets(
      'account edits update the default while explicit Cash is retained',
      (tester) async {
    final account = TextEditingController();
    var method = '';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => SalaryTransferField(
        account: account,
        method: method,
        onChanged: (value) => setState(() => method = value),
      ),
    ))));
    DropdownButtonFormField<String> field() =>
        tester.widget(find.byType(DropdownButtonFormField<String>));
    expect(field().initialValue, '');
    expect(field().items!.map((item) => item.value), ['', 'instant', 'cash']);
    account.text = '0012345';
    await tester.pump();
    expect(field().initialValue, 'rhb');
    field().onChanged!('cash');
    await tester.pump();
    account.clear();
    await tester.pump();
    expect(field().initialValue, 'cash');
    await tester.pumpWidget(const SizedBox());
    account.dispose();
  });
}
