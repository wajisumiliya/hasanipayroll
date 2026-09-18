import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../utils/app_reload.dart';

class AppReloadButton extends StatefulWidget {
  const AppReloadButton({super.key, this.color});

  final Color? color;

  @override
  State<AppReloadButton> createState() => _AppReloadButtonState();
}

class _AppReloadButtonState extends State<AppReloadButton> {
  bool _reloading = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Reload latest version',
      color: widget.color,
      onPressed: _reloading
          ? null
          : () async {
              setState(() => _reloading = true);
              try {
                await reloadLatestApp();
              } catch (_) {
                if (!mounted) return;
                setState(() => _reloading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to reload. Please try again.'),
                  ),
                );
              }
            },
      icon: _reloading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.system_update_alt_outlined),
    );
  }
}
