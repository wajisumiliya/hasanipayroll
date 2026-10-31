import 'dart:async';
import 'dart:collection';

/// Reserves a bounded number of slots; a failure always releases its slot.
class RequestLimiter {
  RequestLimiter(this.limit) : assert(limit > 0);
  final int limit;
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();
  Future<T> run<T>(Future<T> Function() operation) async {
    if (_active >= limit) {
      final waiting = Completer<void>();
      _waiting.add(waiting);
      await waiting.future;
    } else {
      _active++;
    }
    try {
      return await operation();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _active--;
      }
    }
  }
}
