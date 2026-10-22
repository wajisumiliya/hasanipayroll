import 'package:flutter/material.dart';

import 'mystery_egg_teaser.dart';

/// Unrevealed, animated surprises shown on every branch dashboard.
/// Branch accounts do not use the employee-only pet API.
class BranchPenguinCrew extends StatelessWidget {
  const BranchPenguinCrew({super.key, required this.branchName});

  final String branchName;

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
                        itemCount: 6,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 0,
                          mainAxisExtent: 144,
                        ),
                        itemBuilder: (context, index) => const Center(
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
            color: const Color(0xE6FFF1C2),
            borderRadius: BorderRadius.circular(13),
          ),
          child:
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF9A6500)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SIX SECRETS. ONE LITTLE WONDER.',
                style: TextStyle(
                  color: Color(0xFF173D60),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              Text(
                '$branchName · Some surprises are worth waiting for',
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
}
