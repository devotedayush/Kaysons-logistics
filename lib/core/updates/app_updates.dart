import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppUpdatePlatform { android, ios, unsupported }

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  readyToInstall,
  unavailable,
}

/// Play is the source of truth for each user's eligible release track.
/// TestFlight manages iOS notifications and automatic installation itself.
class AppUpdates extends ChangeNotifier {
  AppUpdates({
    AppUpdatePlatform? platform,
    MethodChannel? channel,
    EventChannel? events,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  }) : platform = platform ?? _currentPlatform,
       _channel = channel ?? const MethodChannel(_channelName),
       _events =
           events ??
           const EventChannel(
             'com.kaysons.kaysons_logistics/app_update_events',
           ),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static final AppUpdates instance = AppUpdates();
  static const _channelName = 'com.kaysons.kaysons_logistics/app_updates';
  static const reminderPreference = 'app_update_reminders';
  static const _deferredBuildKey = 'app_update_deferred_build';
  static const _deferredUntilKey = 'app_update_deferred_until';

  static AppUpdatePlatform get _currentPlatform {
    if (kIsWeb) return AppUpdatePlatform.unsupported;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AppUpdatePlatform.android,
      TargetPlatform.iOS => AppUpdatePlatform.ios,
      _ => AppUpdatePlatform.unsupported,
    };
  }

  final AppUpdatePlatform platform;
  final MethodChannel _channel;
  final EventChannel _events;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _initializing;
  SharedPreferences? _prefs;
  DateTime? _lastCheck;
  int? _deferredBuild;
  DateTime? _deferredUntil;
  String? _shownPrompt;
  bool _disposed = false;
  bool _busy = false;
  bool _flowInProgress = false;
  bool remindersEnabled = true;
  AppUpdateStatus status = AppUpdateStatus.idle;
  int? availableVersionCode;
  bool flexibleAllowed = false;

  bool get supported => platform != AppUpdatePlatform.unsupported;
  bool get isAndroid => platform == AppUpdatePlatform.android;
  bool get isIOS => platform == AppUpdatePlatform.ios;
  bool get busy => _busy || _flowInProgress;

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      _prefs = await _preferences();
      remindersEnabled = _prefs!.getBool(reminderPreference) ?? true;
      _deferredBuild = _prefs!.getInt(_deferredBuildKey);
      final until = _prefs!.getInt(_deferredUntilKey);
      if (until != null) {
        _deferredUntil = DateTime.fromMillisecondsSinceEpoch(until);
      }
    } catch (_) {
      // Preferences and the store must never prevent opening the workspace.
    }
    if (_disposed) return;
    if (isAndroid) {
      _subscription = _events.receiveBroadcastStream().listen((event) {
        if (event is Map && !_disposed) _applyInfo(event);
      }, onError: (Object _) {});
    }
    _notify();
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await initialize();
    if (_disposed) return;
    remindersEnabled = enabled;
    _notify();
    try {
      await _prefs?.setBool(reminderPreference, enabled);
    } catch (_) {
      // Keep the user's choice for this session if device storage is unavailable.
    }
    if (enabled) await check(manual: true);
  }

  Future<void> check({bool manual = false}) async {
    await initialize();
    if (!isAndroid || _disposed || busy) return;
    if (!manual) {
      if (!remindersEnabled) return;
      if (_lastCheck != null &&
          _now().difference(_lastCheck!) < const Duration(hours: 6)) {
        return;
      }
    }
    _lastCheck = _now();
    _busy = true;
    status = AppUpdateStatus.checking;
    _notify();
    try {
      final info = await _channel
          .invokeMapMethod<String, dynamic>('checkForUpdate')
          .timeout(const Duration(seconds: 15));
      if (!_disposed) _applyInfo(info ?? const {});
    } catch (_) {
      if (!_disposed) status = AppUpdateStatus.unavailable;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _applyInfo(Map<dynamic, dynamic> info) {
    final version = info['availableVersionCode'];
    if (version is int && version > 0) availableVersionCode = version;
    flexibleAllowed = info['flexibleAllowed'] == true;
    status =
        info['downloaded'] == true
            ? AppUpdateStatus.readyToInstall
            : info['inProgress'] == true
            ? AppUpdateStatus.downloading
            : info['available'] == true
            ? AppUpdateStatus.available
            : AppUpdateStatus.upToDate;
    _notify();
  }

  String get _promptKey => '${availableVersionCode ?? 0}:${status.name}';

  bool get shouldPrompt {
    if (!isAndroid || !remindersEnabled || busy || _disposed) return false;
    if (status != AppUpdateStatus.readyToInstall &&
        status != AppUpdateStatus.available) {
      return false;
    }
    if (_shownPrompt == _promptKey) return false;
    return _deferredBuild != availableVersionCode ||
        _deferredUntil == null ||
        !_now().isBefore(_deferredUntil!);
  }

  void markPromptShown() => _shownPrompt = _promptKey;

  Future<void> remindLater() async {
    _deferredBuild = availableVersionCode;
    _deferredUntil = _now().add(const Duration(days: 1));
    try {
      await _prefs?.setInt(_deferredBuildKey, availableVersionCode ?? 0);
      await _prefs?.setInt(
        _deferredUntilKey,
        _deferredUntil!.millisecondsSinceEpoch,
      );
    } catch (_) {
      // Dismissing an optional reminder must still work if storage is unavailable.
    }
  }

  Future<bool> startUpdate() async {
    if (!isAndroid || busy || status != AppUpdateStatus.available) return false;
    _flowInProgress = true;
    _notify();
    try {
      final accepted = await _channel.invokeMethod<bool>('startFlexibleUpdate');
      if (!_disposed && status != AppUpdateStatus.readyToInstall) {
        status =
            accepted == true
                ? AppUpdateStatus.downloading
                : AppUpdateStatus.available;
      }
      return accepted == true;
    } catch (_) {
      if (!_disposed) status = AppUpdateStatus.unavailable;
      return false;
    } finally {
      _flowInProgress = false;
      _notify();
    }
  }

  Future<void> completeUpdate() async {
    if (!isAndroid || busy || status != AppUpdateStatus.readyToInstall) return;
    _busy = true;
    _notify();
    try {
      await _channel.invokeMethod<bool>('completeUpdate');
    } catch (_) {
      if (!_disposed) status = AppUpdateStatus.unavailable;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
