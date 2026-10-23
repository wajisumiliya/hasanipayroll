import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A confirmed Play update blocks access until the installed build reaches it.
/// Keep the requirement across cancellations, network failures and restarts.
class PlayUpdateController extends ChangeNotifier {
  PlayUpdateController({
    Future<AppUpdateInfo> Function()? check,
    Future<AppUpdateResult> Function()? immediate,
    Future<AppUpdateResult> Function()? flexible,
    Future<void> Function()? complete,
    Future<int> Function()? installedBuild,
    Future<bool> Function()? openStore,
  })  : _check = check ?? InAppUpdate.checkForUpdate,
        _immediate = immediate ?? InAppUpdate.performImmediateUpdate,
        _flexible = flexible ?? InAppUpdate.startFlexibleUpdate,
        _complete = complete ?? InAppUpdate.completeFlexibleUpdate,
        _installedBuild = installedBuild ?? _readBuild,
        _openStore = openStore ?? _launchStore;

  static const _channel = MethodChannel('com.hasani.payroll/play_updates');
  static const _requiredKey = 'play_required_version_code';
  final Future<AppUpdateInfo> Function() _check;
  final Future<AppUpdateResult> Function() _immediate;
  final Future<AppUpdateResult> Function() _flexible;
  final Future<void> Function() _complete;
  final Future<int> Function() _installedBuild;
  final Future<bool> Function() _openStore;
  SharedPreferences? _prefs;
  AppUpdateInfo? _info;
  int _requiredBuild = 0;
  int _currentBuild = 0;
  bool _checking = false;
  bool _disposed = false;
  bool checking = true;
  bool updating = false;
  bool required = false;
  String? message;
  bool get blocked => checking || required;

  static Future<int> _readBuild() async =>
      await _channel.invokeMethod<int>('installedVersionCode') ?? 0;
  static Future<bool> _launchStore() async =>
      await _channel.invokeMethod<bool>('openPlayStore') ?? false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _readInstalled() async {
    _currentBuild =
        await _installedBuild().timeout(const Duration(seconds: 10));
    if (_requiredBuild > 0 && _currentBuild >= _requiredBuild) {
      _requiredBuild = 0;
      await _prefs?.remove(_requiredKey);
    }
    required = _requiredBuild > _currentBuild;
  }

  Future<void> check({bool launchUpdate = true}) async {
    if (_checking || updating || _disposed) return;
    _checking = true;
    checking = true;
    message = null;
    _changed();
    var startUpdate = false;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedBuild = _prefs!.getInt(_requiredKey) ?? 0;
      if (savedBuild > _requiredBuild) {
        _requiredBuild = savedBuild;
      }
      // Load the saved requirement before native calls, so errors cannot unlock it.
      required = _requiredBuild > 0;
      await _readInstalled();
      _info = await _check().timeout(const Duration(seconds: 15));
      final available = _info!.updateAvailability;
      if (available == UpdateAvailability.updateAvailable ||
          available == UpdateAvailability.developerTriggeredUpdateInProgress) {
        final target = _info!.availableVersionCode ?? (_currentBuild + 1);
        if (target > _currentBuild) {
          _requiredBuild = target > _requiredBuild ? target : _requiredBuild;
          required = true;
          await _prefs!.setInt(_requiredKey, _requiredBuild);
        }
        startUpdate = required &&
            launchUpdate &&
            (_info!.immediateUpdateAllowed ||
                _info!.flexibleUpdateAllowed ||
                available ==
                    UpdateAvailability.developerTriggeredUpdateInProgress ||
                _info!.installStatus == InstallStatus.downloaded);
      }
    } catch (_) {
      // No known update: a temporary Play failure must not invent a requirement.
      // Once an update is confirmed, failures never clear its persisted gate.
      if (required) {
        message = 'Unable to check Google Play. Update the app or try again.';
      }
    } finally {
      checking = false;
      _checking = false;
      _changed();
    }
    if (startUpdate && !_disposed) await update();
  }

  Future<void> update() async {
    if (!required || updating || checking || _disposed) return;
    updating = true;
    message = null;
    _changed();
    try {
      final info = _info;
      AppUpdateResult? result;
      if (info?.installStatus == InstallStatus.downloaded) {
        await _complete();
      } else if (info?.immediateUpdateAllowed == true ||
          info?.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress) {
        result = await _immediate();
      } else if (info?.flexibleUpdateAllowed == true) {
        result = await _flexible();
        if (result == AppUpdateResult.success) await _complete();
      } else {
        await openStore();
      }
      if (result == AppUpdateResult.userDeniedUpdate) {
        message = 'Update cancelled. Please update to continue.';
      } else if (result == AppUpdateResult.inAppUpdateFailed) {
        message = 'The update could not finish. Try again or open Google Play.';
      }
      // A success callback alone does not prove installation. Verify the build.
      await _readInstalled();
    } catch (_) {
      message = 'The update could not finish. Try again or open Google Play.';
    } finally {
      updating = false;
      _changed();
    }
  }

  Future<void> openStore() async {
    try {
      if (!await _openStore()) {
        message = 'Unable to open Google Play. Please try again.';
      }
    } catch (_) {
      message = 'Unable to open Google Play. Please try again.';
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
