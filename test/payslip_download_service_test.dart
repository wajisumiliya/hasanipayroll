import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/payslip_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.hasani.payroll/downloads');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'Android download sends PDF bytes and filename to native Downloads',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      expect(
        await PayslipDownloadService.save(bytes, 'payslip_ST001_2026-11.pdf'),
        isTrue,
      );
      expect(calls, hasLength(1));
      expect(calls.single.method, 'savePdf');
      expect(calls.single.arguments['filename'], 'payslip_ST001_2026-11.pdf');
      expect(calls.single.arguments['bytes'], bytes);
    },
  );

  test('storage failure is reported without opening a share sheet', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'DOWNLOAD_FAILED');
    });
    await expectLater(
      PayslipDownloadService.save(Uint8List.fromList([1]), 'payslip.pdf'),
      throwsA(isA<PlatformException>()),
    );
  });
}
