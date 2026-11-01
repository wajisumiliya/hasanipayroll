import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/employee_directory_pagination.dart';

void main() {
  testWidgets('numbered pages and arrows navigate without rendering every page',
      (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EmployeeDirectoryPagination(
                page: 0,
                pageCount: 10,
                onChanged: (value) => selected = value))));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('…'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    await tester.tap(find.text('3'));
    expect(selected, 2);
    await tester.tap(find.byTooltip('Next employees'));
    expect(selected, 1);
    expect(
        tester
            .widget<IconButton>(find.byTooltip('Previous employees'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact last page disables next and shows the page count',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EmployeeDirectoryPagination(
                page: 9, pageCount: 10, compact: true, onChanged: (_) {}))));
    expect(find.text('10 / 10'), findsOneWidget);
    expect(
        tester.widget<IconButton>(find.byTooltip('Next employees')).onPressed,
        isNull);
  });
}
