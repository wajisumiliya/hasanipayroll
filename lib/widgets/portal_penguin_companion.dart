import 'dart:async';
import 'package:flutter/material.dart';
import '../services/mystery_egg_hatch_controller.dart';
import '../services/login_habitat_scene.dart';
import 'employee_penguin_pet_card.dart';

/// Public/session-only companion. Never calls the private employee care API.
class PortalPenguinCompanion extends StatefulWidget {
  const PortalPenguinCompanion(
      {super.key,
      required this.controller,
      this.compact = false,
      this.title = 'YOUR PENGUIN',
      this.loginScene,
      this.matchLoginScene = false,
      this.sceneController});
  final bool matchLoginScene;
  final MysteryEggHatchController? sceneController;
  final LoginHabitatScene? loginScene;
  final MysteryEggHatchController controller;
  final bool compact;
  final String title;
  @override
  State<PortalPenguinCompanion> createState() => _PortalPenguinCompanionState();
}

class _PortalPenguinCompanionState extends State<PortalPenguinCompanion> {
  bool _fed = false, _played = false;
  Timer? _sceneTimer;
  String? _lastSceneAsset;
  MysteryEggHatchController get _sceneClock =>
      widget.sceneController ?? MysteryEggHatchController.shared;
  LoginHabitatScene? get _scene => widget.matchLoginScene
      ? loginHabitatScene(
          instant: _sceneClock.serverNow ??
              widget.controller.serverNow ??
              DateTime.now(),
          hatchAt: _sceneClock.hatchAt,
          hatchConfirmed: _sceneClock.stage != 'egg')
      : widget.loginScene;
  void _bindScene() {
    if (!widget.matchLoginScene) return;
    if (_sceneClock != widget.controller) {
      _sceneClock.addListener(_changed);
      _sceneClock.attach();
    }
    _lastSceneAsset = _scene?.asset;
    _sceneTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final asset = _scene?.asset;
      if (mounted && asset != _lastSceneAsset) {
        _lastSceneAsset = asset;
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.attach();
    _bindScene();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PortalPenguinCompanion old) {
    super.didUpdateWidget(old);
    final rebind = old.matchLoginScene != widget.matchLoginScene ||
        old.sceneController != widget.sceneController ||
        old.controller != widget.controller;
    final oldScene = old.sceneController ?? MysteryEggHatchController.shared;
    if (rebind && old.matchLoginScene && oldScene != old.controller) {
      oldScene.removeListener(_changed);
      oldScene.detach();
    }
    if (rebind) _sceneTimer?.cancel();
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      old.controller.detach();
      widget.controller.addListener(_changed);
      widget.controller.attach();
      _fed = false;
      _played = false;
    }
    if (rebind) _bindScene();
  }

  Future<Map<String, dynamic>> _request(String? kind) async {
    final clock = widget.controller;
    final days = clock.daysSinceHatch;
    final stage = clock.stage;
    if (stage != 'egg') {
      if (kind == 'feed') _fed = true;
      if (kind == 'play') _played = true;
    }
    return {
      'pet': {
        'stage': stage,
        'ageDays': stage == 'egg' ? 0 : days + 3,
        'nickname': 'Pingu',
        'serverNow': clock.serverNow?.toIso8601String(),
        'hatchAt': clock.hatchAt?.toIso8601String(),
        'fedToday': _fed,
        'playedToday': _played
      }
    };
  }

  @override
  void dispose() {
    _sceneTimer?.cancel();
    if (widget.matchLoginScene && _sceneClock != widget.controller) {
      _sceneClock.removeListener(_changed);
      _sceneClock.detach();
    }
    widget.controller.removeListener(_changed);
    widget.controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        EmployeePenguinPetCard(
            key: ValueKey(widget.controller.hatchAt),
            metadataVersion:
                '${widget.controller.stage}|${widget.controller.daysSinceHatch}',
            request: _request,
            localCare: true,
            compact: widget.compact,
            title: widget.title,
            loginScene: _scene),
        if (widget.controller.stage == 'egg')
          Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(widget.controller.countdownLabel,
                  style: const TextStyle(
                      color: Color(0xFF173D60), fontWeight: FontWeight.w600))),
      ]);
}
