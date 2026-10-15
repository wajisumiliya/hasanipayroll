import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'garden_ambience.dart';

class EmployeeGardenCard extends StatefulWidget {
  const EmployeeGardenCard({
    super.key,
    required this.attendanceActive,
    required this.streak,
    required this.milestones,
    required this.availableCare,
    required this.loginsUntilUpgrade,
    required this.loading,
    required this.onCare,
  });

  final bool attendanceActive;
  final int streak;
  final int milestones;
  final int availableCare;
  final int loginsUntilUpgrade;
  final bool loading;
  final Future<bool> Function() onCare;

  @override
  State<EmployeeGardenCard> createState() => _EmployeeGardenCardState();
}

class _EmployeeGardenCardState extends State<EmployeeGardenCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambience;
  bool _caring = false;

  @override
  void initState() {
    super.initState();
    _ambience = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ambience.dispose();
    super.dispose();
  }

  Future<void> _care() async {
    if (_caring || widget.availableCare < 1) return;
    setState(() => _caring = true);
    final cared = await widget.onCare();
    if (!mounted) return;
    setState(() => _caring = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(cared
          ? 'Garden tended — today’s care has been saved.'
          : 'Garden care is not available yet.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final healthy = widget.attendanceActive || widget.streak > 0;
    final progress = widget.loginsUntilUpgrade <= 0
        ? 1.0
        : ((4 - widget.loginsUntilUpgrade) / 4).clamp(0.0, 1.0);
    final level = (widget.milestones ~/ 4 + 1).clamp(1, 6);
    return Container(
      width: double.infinity,
      height: 430,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB99A4B), width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x30000000), blurRadius: 24, offset: Offset(0, 11)),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/employee_garden_courtyard.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: healthy
                    ? const [Color(0x16000000), Color(0xB8001424)]
                    : const [Color(0x66434B53), Color(0xD8192732)],
                stops: const [.38, 1],
              ),
            ),
          ),
          if (!healthy)
            Container(color: const Color(0x303A5266)),
          GardenAmbience(
            animation: _ambience,
            healthy: healthy,
            level: level,
            streak: widget.streak,
          ),
          AnimatedBuilder(
            animation: _ambience,
            builder: (context, _) {
              final pulse = .5 + math.sin(_ambience.value * math.pi * 2) * .5;
              return Stack(children: [
                Positioned(
                  left: MediaQuery.sizeOf(context).width > 700 ? 430 : 190,
                  top: 135,
                  child: Container(
                    width: 46 + pulse * 8,
                    height: 46 + pulse * 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFBFEFFF)
                          .withValues(alpha: .08 + pulse * .06),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBFEFFF)
                              .withValues(alpha: .18 + pulse * .10),
                          blurRadius: 18 + pulse * 9,
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.streak >= 4)
                  Positioned(
                    right: 38,
                    top: 35,
                    child: Icon(Icons.flutter_dash_rounded,
                        color: Colors.white.withValues(alpha: .75),
                        size: 24 + pulse * 3),
                  ),
              ]);
            },
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 17,
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xE8132D27),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.park_rounded,
                    color: Color(0xFFFFD978), size: 27),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MY GARDEN COURTYARD',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            shadows: [Shadow(blurRadius: 8)])),
                    Text('Attendance brings the garden to life',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            shadows: [Shadow(blurRadius: 6)])),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed:
                    widget.availableCare > 0 && !_caring ? _care : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE3BC5A),
                  foregroundColor: const Color(0xFF1C2418),
                  disabledBackgroundColor: const Color(0xCC233B35),
                  disabledForegroundColor: Colors.white70,
                ),
                icon: _caring || widget.loading
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.water_drop_outlined, size: 18),
                label: Text(widget.availableCare > 0
                    ? 'TEND GARDEN ${widget.availableCare}'
                    : 'GARDEN CARED'),
              ),
            ]),
          ),
          Positioned(
            left: 18,
            top: 82,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _feature(Icons.local_florist_rounded, 'Flower beds', level >= 1),
                _feature(Icons.route_rounded, 'Stone path', level >= 2),
                _feature(Icons.chair_alt_rounded, 'Bench', level >= 3),
                _feature(Icons.flutter_dash_rounded, 'Birds', widget.streak >= 3),
                _feature(Icons.home_work_outlined, 'Gazebo', level >= 5),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 15,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xE40B1F26),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _metric(Icons.local_florist_rounded,
                      '${math.max(8, widget.milestones)}', 'Plants'),
                  _metric(Icons.local_fire_department_rounded,
                      '${widget.streak}', 'Login streak'),
                  _metric(Icons.water_rounded,
                      healthy ? 'Flowing' : 'Quiet', 'Fountain'),
                  _metric(Icons.light_mode_rounded,
                      widget.streak >= 4 ? 'Unlocked' : 'Growing', 'Lighting'),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: const Color(0xFFFFD56A),
                    backgroundColor: Colors.white24,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label) => Container(
        width: 132,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(children: [
          Icon(icon, color: const Color(0xFFFFD56A), size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                Text(label,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 9)),
              ],
            ),
          ),
        ]),
      );

  Widget _feature(IconData icon, String label, bool unlocked) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: unlocked ? const Color(0xD91B3B2D) : const Color(0xB9263034),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: unlocked ? const Color(0x88FFD978) : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(unlocked ? icon : Icons.lock_outline_rounded,
              color: unlocked ? const Color(0xFFFFD978) : Colors.white60,
              size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}
