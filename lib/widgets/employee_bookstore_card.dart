import 'dart:math' as math;

import 'package:flutter/material.dart';

class EmployeeBookstoreCard extends StatefulWidget {
  const EmployeeBookstoreCard({
    super.key,
    required this.books,
    required this.availableBooks,
    required this.loginStreak,
    required this.loginsUntilUpgrade,
    required this.loading,
    required this.onAddBook,
  });

  final int books;
  final int availableBooks;
  final int loginStreak;
  final int loginsUntilUpgrade;
  final bool loading;
  final Future<bool> Function() onAddBook;

  @override
  State<EmployeeBookstoreCard> createState() => _EmployeeBookstoreCardState();
}

class _EmployeeBookstoreCardState extends State<EmployeeBookstoreCard> {
  bool _adding = false;

  Future<void> _addBook() async {
    if (_adding || widget.availableBooks < 1) return;
    setState(() => _adding = true);
    await widget.onAddBook();
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final displayBooks = math.max(8, widget.books);
    final customers = math.max(1, widget.loginStreak % 9);
    final progress = widget.loginsUntilUpgrade <= 0
        ? 1.0
        : ((4 - widget.loginsUntilUpgrade) / 4).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 350),
      decoration: BoxDecoration(
        color: const Color(0xFF0E223B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8AE50), width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7A8),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Color(0xFF6B4711)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HASANI BOOKSTORE',
                          style: TextStyle(
                              color: Color(0xFFFFE6A0),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2)),
                      Text('Your attendance grows the store',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      widget.availableBooks > 0 && !_adding ? _addBook : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE4BA59),
                    foregroundColor: const Color(0xFF241703),
                  ),
                  icon: _adding || widget.loading
                      ? const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.library_add_rounded, size: 18),
                  label: Text(widget.availableBooks > 0
                      ? 'ADD BOOK ${widget.availableBooks}'
                      : 'NO BOOKS'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _BookstorePainter(
                bookCount: displayBooks.clamp(8, 40),
                customers: customers.clamp(1, 4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 15),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _stat(Icons.auto_stories_rounded, '$displayBooks', 'Books'),
                    _stat(Icons.groups_rounded, '$customers', 'Customers'),
                    _stat(Icons.local_fire_department_rounded,
                        '${widget.loginStreak}', 'Login streak'),
                    _stat(Icons.upgrade_rounded, '${widget.loginsUntilUpgrade}',
                        'Next upgrade'),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: const Color(0xFFFFD465),
                    backgroundColor: Colors.white12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Container(
        width: 122,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          Icon(icon, color: const Color(0xFFE4BA59), size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 9)),
              ],
            ),
          ),
        ]),
      );
}

class _BookstorePainter extends CustomPainter {
  const _BookstorePainter({required this.bookCount, required this.customers});

  final int bookCount;
  final int customers;

  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()..color = const Color(0xFFF3E5C6);
    canvas.drawRect(Offset.zero & size, wall);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * .77, size.width, size.height * .23),
        Paint()..color = const Color(0xFFB97A45));
    final shelfPaint = Paint()..color = const Color(0xFF704321);
    final shelfWidth = size.width * .58;
    final left = size.width * .055;
    for (var shelf = 0; shelf < 3; shelf++) {
      final top = 18.0 + shelf * 51;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, shelfWidth, 43), const Radius.circular(3)),
        Paint()..color = const Color(0xFF9B6334),
      );
      canvas.drawRect(
          Rect.fromLTWH(left - 3, top + 39, shelfWidth + 6, 6), shelfPaint);
    }
    const colors = [
      Color(0xFFC94B4B),
      Color(0xFF315F91),
      Color(0xFFD49B36),
      Color(0xFF3E8064),
      Color(0xFF7D4F91),
    ];
    for (var i = 0; i < bookCount; i++) {
      final shelf = i % 3;
      final column = i ~/ 3;
      final width = 7.0 + (i % 3) * 2;
      final x = left + 8 + column * 12;
      if (x + width > left + shelfWidth - 4) continue;
      final height = 24.0 + (i % 4) * 4;
      final y = 18 + shelf * 51 + 38 - height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, width, height), const Radius.circular(1.5)),
        Paint()..color = colors[i % colors.length],
      );
      canvas.drawLine(Offset(x + 2, y + 4), Offset(x + width - 2, y + 4),
          Paint()..color = Colors.white54);
    }
    final counter = Rect.fromLTWH(
        size.width * .72, size.height * .47, size.width * .23, 67);
    canvas.drawRRect(RRect.fromRectAndRadius(counter, const Radius.circular(6)),
        Paint()..color = const Color(0xFF17314D));
    canvas.drawRect(Rect.fromLTWH(counter.left, counter.top, counter.width, 6),
        Paint()..color = const Color(0xFFE0B65A));
    for (var i = 0; i < customers; i++) {
      final x = size.width * (.66 + i * .075);
      final y = size.height * (.61 + (i.isOdd ? .05 : 0));
      canvas.drawCircle(
          Offset(x, y - 20), 7, Paint()..color = const Color(0xFFC98D68));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 15, height: 28),
            const Radius.circular(6)),
        Paint()
          ..color =
              i.isEven ? const Color(0xFF284E7B) : const Color(0xFF8D4C51),
      );
    }
    canvas.drawCircle(Offset(size.width * .91, 27), 13,
        Paint()..color = const Color(0xFFFFD56A));
    canvas.drawCircle(Offset(size.width * .91, 27), 7,
        Paint()..color = const Color(0xFFFFF0B7));
  }

  @override
  bool shouldRepaint(covariant _BookstorePainter oldDelegate) =>
      oldDelegate.bookCount != bookCount || oldDelegate.customers != customers;
}
