import 'package:flutter/material.dart';

import '../../core/updates/app_update_prompt.dart';
import '../../core/updates/app_updates.dart';
import '../../l10n/app_localizations.dart';

class AppUpdatesScreen extends StatefulWidget {
  const AppUpdatesScreen({super.key, this.updates});

  final AppUpdates? updates;

  @override
  State<AppUpdatesScreen> createState() => _AppUpdatesScreenState();
}

class _AppUpdatesScreenState extends State<AppUpdatesScreen> {
  late final AppUpdates _updates;

  @override
  void initState() {
    super.initState();
    _updates = widget.updates ?? AppUpdates.instance;
    _updates.initialize();
  }

  Future<void> _open(Uri uri) async {
    final opened = await openAppUpdateLink(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.updatesLinkFailed),
        ),
      );
    }
  }

  String _statusLabel(AppLocalizations l) => switch (_updates.status) {
    AppUpdateStatus.idle => l.updatesPlayHint,
    AppUpdateStatus.checking => l.updatesChecking,
    AppUpdateStatus.upToDate => l.updatesCurrent,
    AppUpdateStatus.available => l.updatesAvailable,
    AppUpdateStatus.downloading => l.updatesDownloading,
    AppUpdateStatus.readyToInstall => l.updatesReady,
    AppUpdateStatus.unavailable => l.updatesUnavailable,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.appUpdates)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(
              listenable: _updates,
              builder:
                  (context, _) => ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_updates.isAndroid) ...[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _updates.remindersEnabled,
                          title: Text(l.updateReminders),
                          subtitle: Text(l.updateRemindersHint),
                          onChanged: _updates.setRemindersEnabled,
                        ),
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _updates.status ==
                                          AppUpdateStatus.readyToInstall
                                      ? Icons.download_done
                                      : Icons.system_update,
                                ),
                                const SizedBox(height: 12),
                                Text(_statusLabel(l)),
                                if (_updates.busy ||
                                    _updates.status ==
                                        AppUpdateStatus.downloading)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: LinearProgressIndicator(),
                                  ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    if (_updates.status ==
                                        AppUpdateStatus.available)
                                      FilledButton.icon(
                                        onPressed:
                                            _updates.busy
                                                ? null
                                                : () => startAppUpdate(
                                                  context,
                                                  _updates,
                                                ),
                                        icon: const Icon(Icons.download),
                                        label: Text(l.updateNow),
                                      )
                                    else if (_updates.status ==
                                        AppUpdateStatus.readyToInstall)
                                      FilledButton.icon(
                                        onPressed:
                                            _updates.busy
                                                ? null
                                                : _updates.completeUpdate,
                                        icon: const Icon(Icons.restart_alt),
                                        label: Text(l.updateRestart),
                                      )
                                    else
                                      FilledButton.icon(
                                        onPressed:
                                            _updates.busy ||
                                                    _updates.status ==
                                                        AppUpdateStatus
                                                            .downloading
                                                ? null
                                                : () => _updates.check(
                                                  manual: true,
                                                ),
                                        icon: const Icon(Icons.refresh),
                                        label: Text(l.checkForUpdates),
                                      ),
                                    TextButton(
                                      onPressed: () => _open(googlePlayAppUri),
                                      child: Text(l.updatesOpenPlay),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(l.updatesPlayHint),
                      ] else if (_updates.isIOS) ...[
                        const Icon(Icons.system_update, size: 36),
                        const SizedBox(height: 16),
                        Text(
                          l.updatesTestFlightTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(l.updatesTestFlightBody),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () => _open(testFlightHelpUri),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(l.updatesTestFlightHelp),
                        ),
                      ] else
                        Text(l.updatesUnsupported),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
