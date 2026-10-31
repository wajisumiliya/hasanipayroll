import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/request_limiter.dart';

void main() {
  test('bounds concurrent requests and releases slots after failure', () async {
    final limiter = RequestLimiter(4);
    var active = 0;
    var peak = 0;
    final gates = List.generate(12, (_) => Completer<void>());
    final requests = List.generate(
        12,
        (i) => limiter.run(() async {
              active++;
              if (active > peak) peak = active;
              try {
                await gates[i].future;
                if (i == 0) throw StateError('Network unavailable');
                return i;
              } finally {
                active--;
              }
            }).then<int?>((value) => value, onError: (Object _) => null));
    await Future<void>.delayed(Duration.zero);
    expect(active, 4);
    gates[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(active, 4);
    for (final gate in gates.skip(1)) gate.complete();
    final values = await Future.wait(requests);
    expect(peak, 4);
    expect(active, 0);
    expect(values.whereType<int>().length, 11);
    expect(await limiter.run(() async => 99), 99);
  });
}
