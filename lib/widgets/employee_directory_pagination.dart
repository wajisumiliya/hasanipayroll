import 'package:flutter/material.dart';

class EmployeeDirectoryPagination extends StatelessWidget {
  const EmployeeDirectoryPagination(
      {super.key,
      required this.page,
      required this.pageCount,
      required this.onChanged,
      this.compact = false});
  final int page, pageCount;
  final bool compact;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final visible = <int>{
      0,
      pageCount - 1,
      for (var i = page - 2; i <= page + 2; i++)
        if (i >= 0 && i < pageCount) i,
      if (page < 3)
        for (var i = 0; i < 5 && i < pageCount; i++) i,
      if (pageCount - page < 4)
        for (var i = pageCount - 5; i < pageCount; i++)
          if (i >= 0) i,
    }.where((i) => i >= 0 && i < pageCount).toList()
      ..sort();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          tooltip: 'Previous employees',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: page > 0 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left)),
      if (compact)
        Text('${pageCount == 0 ? 0 : page + 1} / $pageCount',
            style: const TextStyle(fontSize: 11))
      else
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0 && visible[index] > visible[index - 1] + 1)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5), child: Text('…')),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                  width: 28,
                  height: 28,
                  child: TextButton(
                      onPressed: () => onChanged(visible[index]),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          backgroundColor: visible[index] == page
                              ? const Color(0xFFE4EAFE)
                              : Colors.transparent,
                          foregroundColor: visible[index] == page
                              ? const Color(0xFF2149BC)
                              : const Color(0xFF53617B),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7))),
                      child: Text('${visible[index] + 1}',
                          style: const TextStyle(fontSize: 11))))),
        ],
      IconButton(
          tooltip: 'Next employees',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: page + 1 < pageCount ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right)),
    ]);
  }
}
