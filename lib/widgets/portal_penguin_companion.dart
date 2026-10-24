import 'package:flutter/material.dart';
import '../services/mystery_egg_hatch_controller.dart';
import '../services/login_habitat_scene.dart';
import 'employee_penguin_pet_card.dart';
import 'branch_penguin_crew.dart';

/// Public/session-only companion. Never calls the private employee care API.
class PortalPenguinCompanion extends StatefulWidget {
  const PortalPenguinCompanion(
      {super.key,
      required this.controller,
      this.compact = false,
      this.title = 'YOUR PENGUIN',
      this.loginScene,
      this.familyBranchName});
  final String? familyBranchName;
  final LoginHabitatScene? loginScene;
  final MysteryEggHatchController controller;
  final bool compact;
  final String title;
  @override
  State<PortalPenguinCompanion> createState() => _PortalPenguinCompanionState();
}

class _PortalPenguinCompanionState extends State<PortalPenguinCompanion> {
  bool _fed = false, _played = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.attach();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PortalPenguinCompanion old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      old.controller.detach();
      widget.controller.addListener(_changed);
      widget.controller.attach();
      _fed = false;
      _played = false;
    }
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
            loginScene: widget.loginScene,
            habitatBuilder: widget.familyBranchName == null
                ? null
                : (character, action, reactionId) => BranchPenguinCrew(
                    branchName: widget.familyBranchName!,
                    controller: widget.controller,
                    embedded: true,
                    companion: character,
                    companionAction: action,
                    reactionId: reactionId)),
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
