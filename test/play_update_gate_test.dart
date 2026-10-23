import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hasani_payroll_portal/services/play_update_service.dart';
import 'package:hasani_payroll_portal/widgets/play_update_gate.dart';

AppUpdateInfo info(
        {UpdateAvailability availability = UpdateAvailability.updateAvailable,
        bool immediate = true,
        bool flexible = false,
        InstallStatus install = InstallStatus.unknown}) =>
    AppUpdateInfo(
      updateAvailability: availability,
      immediateUpdateAllowed: immediate,
      flexibleUpdateAllowed: flexible,
      immediateAllowedPreconditions: [],
      flexibleAllowedPreconditions: [],
      availableVersionCode: 26,
      installStatus: install,
      packageName: 'com.hasani.payroll',
      clientVersionStalenessDays: 1,
      updatePriority: 5,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'no Play update allows access; an unknown check failure invents no requirement',
      () async {
    final current = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async =>
            info(availability: UpdateAvailability.updateNotAvailable));
    await current.check();
    expect(current.blocked, false);
    current.dispose();
    final offline = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async => throw Exception('offline'));
    await offline.check();
    expect(offline.blocked, false);
    offline.dispose();
  });

  test(
      'cancelling a confirmed update stays blocked across restart and Play failure',
      () async {
    var immediateCalls = 0;
    final first = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async => info(),
        immediate: () async {
          immediateCalls++;
          return AppUpdateResult.userDeniedUpdate;
        });
    await first.check();
    expect(immediateCalls, 1);
    expect(first.blocked, true);
    expect(first.message, contains('cancelled'));
    first.dispose();
    final restarted = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async => throw Exception('offline'));
    await restarted.check();
    expect(restarted.blocked, true);
    restarted.dispose();
    final upgraded = PlayUpdateController(
        installedBuild: () async => 26,
        check: () async => throw Exception('offline'));
    await upgraded.check();
    expect(upgraded.blocked, false);
    upgraded.dispose();
  });

  test('a success callback cannot unlock the old installed build', () async {
    var build = 25;
    var available = true;
    final controller = PlayUpdateController(
        installedBuild: () async => build,
        check: () async => info(
            availability: available
                ? UpdateAvailability.updateAvailable
                : UpdateAvailability.updateNotAvailable),
        immediate: () async => AppUpdateResult.success);
    await controller.check();
    expect(controller.required, true);
    build = 26;
    available = false;
    await controller.check();
    expect(controller.blocked, false);
    controller.dispose();
  });

  test('interrupted immediate updates resume even if immediateAllowed is false',
      () async {
    var calls = 0;
    final controller = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async => info(
            availability: UpdateAvailability.developerTriggeredUpdateInProgress,
            immediate: false),
        immediate: () async {
          calls++;
          return AppUpdateResult.inAppUpdateFailed;
        });
    await controller.check();
    expect(calls, 1);
    expect(controller.blocked, true);
    controller.dispose();
  });

  test(
      'flexible update still blocks access and only completes after download succeeds',
      () async {
    var completions = 0;
    var result = AppUpdateResult.userDeniedUpdate;
    final controller = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async => info(immediate: false, flexible: true),
        flexible: () async => result,
        complete: () async {
          completions++;
        });
    await controller.check();
    expect(completions, 0);
    expect(controller.blocked, true);
    result = AppUpdateResult.success;
    await controller.update();
    expect(completions, 1);
    expect(controller.blocked, true); // Install/restart has not happened yet.
    controller.dispose();
  });

  test('store fallback never clears the requirement', () async {
    var opens = 0;
    final controller = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async => info(immediate: false),
        openStore: () async {
          opens++;
          return true;
        });
    await controller.check();
    expect(opens, 0); // Returning from Play must not create a redirect loop.
    await controller.update();
    expect(opens, 1);
    expect(controller.blocked, true);
    controller.dispose();
  });

  testWidgets(
      'an unresponsive Play check times out and preserves any known requirement',
      (tester) async {
    for (final known in [false, true]) {
      SharedPreferences.setMockInitialValues(
          known ? {'play_required_version_code': 26} : {});
      final controller = PlayUpdateController(
          installedBuild: () async => 25,
          check: () => Completer<AppUpdateInfo>().future);
      final pending = controller.check();
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await pending;
      expect(controller.blocked, known);
      controller.dispose();
    }
  });

  testWidgets('gate covers restored routes and has no Later bypass',
      (tester) async {
    var protectedTaps = 0;
    final navigator = GlobalKey<NavigatorState>();
    final controller = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async => info(),
        immediate: () async => AppUpdateResult.userDeniedUpdate);
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => PlayUpdateGate(
            enabled: true, controller: controller, child: child!),
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomLeft,
                child: TextButton(
                    key: const Key('protected'),
                    onPressed: () => protectedTaps++,
                    child: const Text('Payroll'))))));
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    await tester.tap(find.byKey(const Key('protected')), warnIfMissed: false);
    expect(protectedTaps, 0);
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Another portal'))));
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('resume rechecks for newly available updates', (tester) async {
    var available = false;
    final controller = PlayUpdateController(
        installedBuild: () async => 25,
        check: () async => info(
            availability: available
                ? UpdateAvailability.updateAvailable
                : UpdateAvailability.updateNotAvailable),
        immediate: () async => AppUpdateResult.userDeniedUpdate);
    await tester.pumpWidget(MaterialApp(
        home: PlayUpdateGate(
            enabled: true,
            controller: controller,
            child: const Scaffold(body: Text('Payroll portal')))));
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsNothing);
    available = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('web and other unsupported platforms bypass the Play gate',
      (tester) async {
    var calls = 0;
    final controller = PlayUpdateController(check: () async {
      calls++;
      return info();
    });
    await tester.pumpWidget(MaterialApp(
        home: PlayUpdateGate(
            enabled: false,
            controller: controller,
            child: const Scaffold(body: Text('Web login')))));
    expect(find.text('Web login'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
