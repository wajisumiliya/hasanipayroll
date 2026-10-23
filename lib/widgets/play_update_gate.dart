import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/play_update_service.dart';

/// Wraps the whole Navigator, including restored sessions and subsequent routes.
class PlayUpdateGate extends StatefulWidget {
  const PlayUpdateGate(
      {super.key, required this.child, this.controller, this.enabled});
  final Widget child;
  final PlayUpdateController? controller;
  final bool? enabled;
  @override
  State<PlayUpdateGate> createState() => _PlayUpdateGateState();
}

class _PlayUpdateGateState extends State<PlayUpdateGate>
    with WidgetsBindingObserver {
  late final _controller = widget.controller ?? PlayUpdateController();
  bool get _enabled =>
      widget.enabled ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_controller.check());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_enabled && state == AppLifecycleState.resumed) {
      unawaited(_controller.check());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final blocked = _controller.blocked;
          final busy = _controller.checking || _controller.updating;
          return Stack(fit: StackFit.expand, children: [
            ExcludeSemantics(
                excluding: blocked,
                child: ExcludeFocus(
                    excluding: blocked,
                    child: AbsorbPointer(
                        absorbing: blocked, child: widget.child))),
            if (blocked)
              Positioned.fill(
                  child: Material(
                color: const Color(0xFFF2F6FC),
                child: SafeArea(
                    child: Center(
                        child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.system_update_rounded,
                          size: 64, color: Color(0xFF08255F)),
                      const SizedBox(height: 20),
                      Text(
                          _controller.checking
                              ? 'Checking for updates…'
                              : 'Update required',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                          _controller.checking
                              ? 'Please wait while we check Google Play.'
                              : 'Please update Hasani Books from Google Play to continue.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      if (busy) const CircularProgressIndicator(),
                      if (!busy) ...[
                        FilledButton.icon(
                            onPressed: _controller.update,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Update now')),
                        TextButton(
                            onPressed: _controller.openStore,
                            child: const Text('Open Google Play')),
                        TextButton(
                            onPressed: () => _controller.check(),
                            child: const Text('Check again')),
                      ],
                      if (_controller.message != null) ...[
                        const SizedBox(height: 16),
                        Text(_controller.message!, textAlign: TextAlign.center),
                      ],
                    ]),
                  ),
                ))),
              )),
          ]);
        });
  }
}
