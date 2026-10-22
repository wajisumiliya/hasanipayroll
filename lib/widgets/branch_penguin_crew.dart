import 'package:flutter/material.dart';

import 'employee_penguin_pet_card.dart' show PenguinIllustration;
import 'mystery_egg_teaser.dart';

/// Decorative, animated penguin crew shown on every branch dashboard.
/// Branch accounts do not use the employee-only pet API.
class BranchPenguinCrew extends StatelessWidget {
  const BranchPenguinCrew({super.key, required this.branchName});

  final String branchName;

  static const _penguins = [
    ('Pip', 'adult', 'waddling', 'Grown-up'),
    ('Poppy', 'chick', 'eating', 'Little one'),
    ('Pebble', 'juvenile', 'playing', 'Youngster'),
    ('Nori', 'chick', 'idle', 'Little one'),
    ('Skipper', 'juvenile', 'waddling', 'Youngster'),
  ];

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFFB9DDED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14245A78),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/penguin_habitat.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66F4FBFF),
                      Color(0x22FFFFFF),
                      Color(0x33EAF7FF),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1160
                          ? 6
                          : constraints.maxWidth >= 760
                              ? 4
                              : constraints.maxWidth >= 480
                                  ? 3
                                  : 2;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _penguins.length + 1,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 0,
                          mainAxisExtent: 144,
                        ),
                        itemBuilder: (context, index) =>
                            index < _penguins.length
                                ? _penguinTile(_penguins[index])
                                : const Center(
                                    child: MysteryEggTeaser(size: 128),
                                  ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xD9D1F0FC),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.ac_unit_rounded, color: Color(0xFF1D648A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THE PENGUIN CREW',
                style: TextStyle(
                  color: Color(0xFF173D60),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              Text(
                '$branchName · Five branch penguins',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF426680),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _penguinTile((String, String, String, String) penguin) {
    final (name, stage, action, label) = penguin;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 108,
          child: FittedBox(
            fit: BoxFit.contain,
            child: PenguinIllustration(stage: stage, action: action),
          ),
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF173D60),
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Color(0xBFFFFFFF), blurRadius: 5)],
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF426680),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Color(0xBFFFFFFF), blurRadius: 5)],
          ),
        ),
      ],
    );
  }
}
