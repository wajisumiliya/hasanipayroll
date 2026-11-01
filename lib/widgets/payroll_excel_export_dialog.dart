import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PayrollExcelExportDialog extends StatefulWidget {
  const PayrollExcelExportDialog(
      {super.key, required this.initialMonth, required this.onGenerate});
  final DateTime initialMonth;
  final Future<bool> Function(DateTime month, Set<String> files) onGenerate;
  @override
  State<PayrollExcelExportDialog> createState() =>
      _PayrollExcelExportDialogState();
}

class _PayrollExcelExportDialogState extends State<PayrollExcelExportDialog> {
  late int year = widget.initialMonth.year, month = widget.initialMonth.month;
  final selectedFiles = <String>{
    'Branch Payroll',
    'EPF',
    'SOCSO',
    'EIS',
    'HRDF'
  };
  bool busy = false;
  String? error;
  static const ink = Color(0xFF0B2859);
  Future<void> generate() async {
    if (busy || selectedFiles.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final success = await widget.onGenerate(
          DateTime(year, month), Set<String>.of(selectedFiles));
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => error =
            'Export was not completed. Check the payroll data and try again.');
      }
    } catch (_) {
      if (mounted)
        setState(() => error = 'Unable to generate files. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastYear = DateTime.now().year > year ? DateTime.now().year : year;
    final years =
        List.generate(lastYear - 2019 + 1, (index) => lastYear - index);
    InputDecoration decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFCFCFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8D0DE))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8D0DE))));
    return PopScope(
        canPop: !busy,
        child: AlertDialog(
          scrollable: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Image.asset('assets/hasani_books_logo.jpg',
                width: 95, height: 40, fit: BoxFit.contain),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Generate Payroll Excel Files',
                    style: TextStyle(fontSize: 23, color: Color(0xFF19283F))))
          ]),
          content: SizedBox(
              width: 660,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Select the payroll month, year, and file types to generate.',
                        style:
                            TextStyle(color: Color(0xFF77777E), height: 1.5)),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<int>(
                              key: const Key('payroll-export-month'),
                              initialValue: month,
                              decoration: decoration('Month'),
                              style: const TextStyle(
                                  color: ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                              isExpanded: true,
                              items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text(DateFormat('MMMM')
                                          .format(DateTime(2000, i + 1))))),
                              onChanged: busy
                                  ? null
                                  : (value) {
                                      if (value != null)
                                        setState(() => month = value);
                                    })),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DropdownButtonFormField<int>(
                              key: const Key('payroll-export-year'),
                              initialValue: year,
                              decoration: decoration('Year'),
                              style: const TextStyle(
                                  color: ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                              isExpanded: true,
                              items: years
                                  .map((y) => DropdownMenuItem(
                                      value: y, child: Text('$y')))
                                  .toList(),
                              onChanged: busy
                                  ? null
                                  : (value) {
                                      if (value != null)
                                        setState(() => year = value);
                                    })),
                    ]),
                    const SizedBox(height: 20),
                    Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(children: [
                          for (final file in const [
                            'Branch Payroll',
                            'EPF',
                            'SOCSO',
                            'EIS',
                            'HRDF'
                          ])
                            CheckboxListTile(
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: ink,
                                title: Text(file,
                                    style: const TextStyle(color: ink)),
                                value: selectedFiles.contains(file),
                                onChanged: busy
                                    ? null
                                    : (checked) => setState(() {
                                          if (checked == true) {
                                            selectedFiles.add(file);
                                          } else {
                                            selectedFiles.remove(file);
                                          }
                                        }))
                        ])),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(error!,
                              style: const TextStyle(color: Colors.red))),
                  ])),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton.icon(
                onPressed: busy || selectedFiles.isEmpty ? null : generate,
                style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download, size: 18),
                label: Text(busy ? 'Generating...' : 'Generate Selected Files'))
          ],
        ));
  }
}
