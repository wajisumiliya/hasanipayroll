import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'neon_api.dart';

/// Shared public launch clock. Device time never decides when to reveal a pet.
class MysteryEggHatchController extends ChangeNotifier
    with WidgetsBindingObserver {
  MysteryEggHatchController({Future<Map<String, dynamic>> Function()? load})
      : _load = load ?? _fetch;

  static final shared = MysteryEggHatchController();
  final Future<Map<String, dynamic>> Function() _load;
  String _stage = 'egg';
  bool _hatching = false;
  bool _loading = false;
  bool _disposed = false;
  int _users = 0;
  int _generation = 0;
  Timer? _poll;
  Timer? _crack;
  Timer? _hatch;

  String get stage => _stage;
  bool get hatching => _hatching;

  static Future<Map<String, dynamic>> _fetch() async {
    final response = await http
        .get(Uri.parse('${NeonApi.baseUrl}/api/mystery-eggs'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('Surprise unavailable');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] != true) throw StateError('Surprise unavailable');
    return Map<String, dynamic>.from(body['egg'] as Map);
  }

  void attach() {
    if (_disposed) return;
    if (++_users != 1) return;
    WidgetsBinding.instance.addObserver(this);
    _poll =
        Timer.periodic(const Duration(minutes: 5), (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  void detach() {
    if (_users == 0 || --_users != 0) return;
    _generation++;
    _loading = false;
    _cancelTimers();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _cancelTimers() {
    _poll?.cancel();
    _crack?.cancel();
    _hatch?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _users > 0) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_loading || _disposed || _users == 0) return;
    _loading = true;
    final generation = _generation;
    try {
      final data = await _load();
      if (_disposed || _users == 0 || generation != _generation) return;
      final hatchAt = DateTime.parse(data['hatchAt'] as String);
      final serverNow = DateTime.parse(data['serverNow'] as String);
      final stage = data['stage'];
      if (!['egg', 'chick', 'juvenile', 'adult'].contains(stage) ||
          (stage != 'egg' && serverNow.isBefore(hatchAt))) {
        throw StateError('Invalid hatch state');
      }
      final remaining = hatchAt.difference(serverNow);
      _stage = stage as String;
      _hatching = stage == 'egg' && remaining <= const Duration(minutes: 5);
      _crack?.cancel();
      _hatch?.cancel();
      if (stage == 'egg') {
        if (remaining > const Duration(minutes: 5)) {
          _crack = Timer(remaining - const Duration(minutes: 5), () {
            if (_disposed || _users == 0) return;
            _hatching = true;
            notifyListeners();
          });
        }
        // Confirm the reveal with the server; never guess from the device clock.
        _hatch = Timer(
          remaining > Duration.zero ? remaining : const Duration(seconds: 1),
          () => unawaited(refresh()),
        );
      }
      notifyListeners();
    } catch (_) {
      // Stay sealed if the first load fails. Periodic/resume refresh retries;
      // already confirmed hatch progress is kept through temporary outages.
    } finally {
      if (generation == _generation) _loading = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelTimers();
    if (_users > 0) WidgetsBinding.instance.removeObserver(this);
    _users = 0;
    super.dispose();
  }
}
