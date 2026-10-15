import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Google Play in-app update prompt for installed Android releases.
/// Updates are only available after Play distributes a newer version.
class PlayUpdateService {
  PlayUpdateService._();

  static bool _checking = false;

  static Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _checking) {
      return;
    }
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !context.mounted) {
        return;
      }
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hasani Payroll update available'),
          content: const Text(
            'A newer version is available on Google Play. '
            'Update now to receive the latest improvements.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Update now'),
            ),
          ],
        ),
      );
      if (approved != true) return;

      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (_) {
      // Updates are unavailable for sideloaded APKs, some test tracks,
      // and devices without Play Store. Never block payroll access.
    } finally {
      _checking = false;
    }
  }
}
