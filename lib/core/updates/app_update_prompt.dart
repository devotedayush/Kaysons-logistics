import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'app_updates.dart';

Future<bool> openAppUpdateLink(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

final googlePlayAppUri = Uri.https('play.google.com', '/store/apps/details', {
  'id': 'com.kaysons.kaysons_logistics',
});
final testFlightHelpUri = Uri.https('testflight.apple.com');

Future<void> startAppUpdate(BuildContext context, AppUpdates updates) async {
  if (updates.flexibleAllowed) {
    await updates.startUpdate();
  } else {
    final opened = await openAppUpdateLink(googlePlayAppUri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.updatesLinkFailed),
        ),
      );
    }
  }
}

/// Sits above the router and uses its overlay so prompts work for every role.
class AppUpdatePrompt extends StatefulWidget {
  const AppUpdatePrompt({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.updates,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final AppUpdates? updates;

  @override
  State<AppUpdatePrompt> createState() => _AppUpdatePromptState();
}

class _AppUpdatePromptState extends State<AppUpdatePrompt>
    with WidgetsBindingObserver {
  late final AppUpdates _updates;
  bool _showing = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _updates = widget.updates ?? AppUpdates.instance;
    WidgetsBinding.instance.addObserver(this);
    _updates.addListener(_onUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_updates.check());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_updates.check());
  }

  void _onUpdate() {
    if (!mounted || _showing || _scheduled || !_updates.shouldPrompt) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_showPrompt());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _showPrompt() async {
    final context = widget.navigatorKey.currentState?.overlay?.context;
    if (context == null || !context.mounted || !_updates.shouldPrompt) return;
    _showing = true;
    _updates.markPromptShown();
    final ready = _updates.status == AppUpdateStatus.readyToInstall;
    final l = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: Icon(ready ? Icons.download_done : Icons.system_update),
            title: Text(ready ? l.updateRestartTitle : l.updatePromptTitle),
            content: Text(ready ? l.updateRestartBody : l.updatePromptBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.updateLater),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(ready ? l.updateRestart : l.updateNow),
              ),
            ],
          ),
    );
    if (accepted != true) {
      await _updates.remindLater();
    } else if (ready) {
      await _updates.completeUpdate();
    } else if (context.mounted) {
      await startAppUpdate(context, _updates);
    }
    _showing = false;
    if (mounted) _onUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updates.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
