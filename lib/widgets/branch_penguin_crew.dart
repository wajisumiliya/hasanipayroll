import 'package:flutter/material.dart';

import 'employee_penguin_pet_card.dart' show PenguinIllustration;

/// Decorative, animated penguin trio shown on every branch dashboard.
/// Branch accounts do not use the employee-only pet API.
class BranchPenguinCrew extends StatelessWidget {
  const BranchPenguinCrew({super.key, required this.branchName});

  final String branchName;

  static const _penguins = [
    ('Pip', 'adult', 'idle'),
    ('Poppy', 'chick', 'waddling'),
    ('Pebble', 'juvenile', 'playing'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F7FF), Color(0xFFF9FCFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB9DDED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14245A78),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1F0FC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.ac_unit_rounded,
                  color: Color(0xFF1D648A),
                ),
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
                      '$branchName · Three branch penguins',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF426680),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 20) / 3;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < _penguins.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    SizedBox(
                      width: tileWidth,
                      child: _penguinTile(_penguins[index], index),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _penguinTile((String, String, String) penguin, int index) {
    final (name, stage, action) = penguin;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 112,
          child: FittedBox(
            fit: BoxFit.contain,
            child: PenguinIllustration(
              stage: stage,
              action: action,
            ),
          ),
        ),
        Text(
          name,
          style: const TextStyle(
            color: Color(0xFF173D60),
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          ['Grown-up', 'Little one', 'Youngster'][index],
          style: const TextStyle(color: Color(0xFF678398), fontSize: 10),
        ),
      ],
    );
  }
}
