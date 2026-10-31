import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hasani_payroll_portal/screens/qr_attendance_page.dart';
import 'package:hasani_payroll_portal/services/qr_attendance_service.dart';
import 'package:hasani_payroll_portal/services/neon_api.dart';

class FakeQrGateway extends QrAttendanceGateway {
  bool supervised = false,
      uncertain = false,
      recoveryFound = true,
      rateLimited = false;
  int punches = 0;
  final bodies = <Map<String, dynamic>>[];
  Map<String, dynamic> get recorded => {
        'ok': true,
        'event_id': '10',
        'action': 'IN',
        'employee_id': 'E1',
        'name': 'Employee One',
        'branch_id': 'A',
        'work_date': '2026-10-31',
        'scanned_at': '2026-10-31T01:00:00Z'
      };
  @override
  Future<Map<String, dynamic>> get(String path,
      [Map<String, String> query = const {}]) async {
    if (path == '/stations') {
      return {
        'ok': true,
        'stations': [
          {
            'id': 'station1',
            'label': 'Scanner 1',
            'branch_id': 'A',
            'enabled': true
          }
        ]
      };
    }
    if (path.startsWith('/requests/')) {
      return recoveryFound ? recorded : {'ok': true, 'state': 'NOT_FOUND'};
    }
    throw StateError(path);
  }

  @override
  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    if (path == '/session') return {'ok': true, 'id': 'session1'};
    if (path == '/preview') {
      return {
        'ok': true,
        'employee': {
          'employee_id': 'E1',
          'name': 'Employee One',
          'branch_id': 'A'
        },
        'verification_token': 'ticket',
        'verification_required': supervised
      };
    }
    if (path == '/requests/cancel') return {'ok': true, 'cancelled': true};
    if (path == '/scan') {
      if (rateLimited) {
        throw const NeonApiException('Wait', 429, 'RATE_LIMITED');
      }
      punches++;
      bodies.add(body);
      if (uncertain) throw TimeoutException('Network unavailable');
      return recorded;
    }
    throw StateError(path);
  }
}

Future<void> open(WidgetTester tester, FakeQrGateway gateway) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: QrAttendancePage(gateway: gateway))));
  await tester.pumpAndSettle();
  if (find.text('Start scanner session').evaluate().isNotEmpty) {
    await tester.tap(find.text('Start scanner session'));
    await tester.pumpAndSettle();
  }
}

Future<void> scan(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'HBQR1_testcredential');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'HID Enter records only after server confirmation and shows Malaysia time',
      (tester) async {
    final gateway = FakeQrGateway();
    await open(tester, gateway);
    await scan(tester);
    expect(gateway.punches, 1);
    expect(find.text('IN RECORDED'), findsOneWidget);
    expect(find.textContaining('9:00:00 AM'), findsOneWidget);
    expect(gateway.bodies.single['request_id'], isNotNull);
    expect((await SharedPreferences.getInstance()).getString('qr_pending_null'),
        isNull);
  });
  testWidgets(
      'supervised stations require a photo-verification action before recording',
      (tester) async {
    final gateway = FakeQrGateway()..supervised = true;
    await open(tester, gateway);
    await scan(tester);
    expect(gateway.punches, 0);
    expect(find.text('IN RECORDED'), findsNothing);
    await tester.tap(find.text('Photo verified — record punch'));
    await tester.pumpAndSettle();
    expect(gateway.punches, 1);
    expect(gateway.bodies.single['verification_token'], 'ticket');
  });
  testWidgets(
      'uncertain result persists only identifiers and recovers without a second punch',
      (tester) async {
    final gateway = FakeQrGateway()..uncertain = true;
    await open(tester, gateway);
    await scan(tester);
    expect(find.text('IN RECORDED'), findsNothing);
    expect(gateway.punches, 1);
    final pending =
        (await SharedPreferences.getInstance()).getString('qr_pending_null')!;
    expect(pending.contains('HBQR1_'), isFalse);
    expect(pending.contains('ticket'), isFalse);
    await tester.tap(find.text('Check pending request result'));
    await tester.pumpAndSettle();
    expect(find.text('IN RECORDED'), findsOneWidget);
    expect(gateway.punches, 1);
  });
  testWidgets(
      'page reload checks an existing request before accepting any new scan',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'qr_pending_null': jsonEncode({
        'request_id': 'request1',
        'session_id': 'session1',
        'employee_id': 'E1'
      })
    });
    final gateway = FakeQrGateway();
    await open(tester, gateway);
    expect(find.text('IN RECORDED'), findsOneWidget);
    expect(gateway.punches, 0);
  });
  testWidgets('a retry keeps the original request identifier until confirmed',
      (tester) async {
    final gateway = FakeQrGateway()
      ..uncertain = true
      ..recoveryFound = false;
    await open(tester, gateway);
    await scan(tester);
    gateway.uncertain = false;
    await scan(tester);
    expect(gateway.bodies.length, 2);
    expect(gateway.bodies[0]['request_id'], gateway.bodies[1]['request_id']);
    expect(find.text('IN RECORDED'), findsOneWidget);
  });
  testWidgets(
      'a response before a durable receipt cannot discard an unresolved request',
      (tester) async {
    final gateway = FakeQrGateway()..rateLimited = true;
    await open(tester, gateway);
    await scan(tester);
    expect((await SharedPreferences.getInstance()).getString('qr_pending_null'),
        isNotNull);
    expect(find.text('IN RECORDED'), findsNothing);
    await tester.tap(find.text('Cancel unresolved request safely'));
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('qr_pending_null'),
        isNull);
    expect(find.text('IN RECORDED'), findsNothing);
    expect(find.textContaining('No punch was recorded'), findsOneWidget);
  });
  testWidgets('scanner layout fits a small phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QrAttendancePage(gateway: FakeQrGateway()))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
