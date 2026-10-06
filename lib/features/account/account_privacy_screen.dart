import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/legal_links.dart';
import '../../core/supabase/account_deletion_service.dart';
import '../../core/supabase/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../auth/enrollment_strings.dart';

class AccountPrivacyScreen extends StatefulWidget {
  const AccountPrivacyScreen({super.key});

  @override
  State<AccountPrivacyScreen> createState() => _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends State<AccountPrivacyScreen> {
  AccountDeletionRequest? _activeRequest;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final request = await AccountDeletionService.instance.activeRequest();
      if (mounted) setState(() => _activeRequest = request);
    } catch (error) {
      if (mounted) {
        _showError('${AppLocalizations.of(context)!.privacyLoadError}: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) _showError(AppLocalizations.of(context)!.privacyOpenError);
    }
  }

  Future<void> _requestDeletion() async {
    final l = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    var confirmed = false;
    final shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.privacyDeleteTitle,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l.privacyDeleteWarning,
                            style: const TextStyle(height: 1.45),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: reasonController,
                            maxLength: 1000,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: l.privacyReason,
                              hintText: l.privacyReasonHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: confirmed,
                              onChanged:
                                  (value) => setSheetState(
                                    () => confirmed = value ?? false,
                                  ),
                              title: Text(
                                l.privacyConfirm,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                ),
                                onPressed:
                                    confirmed ? () => context.pop(true) : null,
                                child: Text(l.privacySubmit),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => context.pop(false),
                                child: Text(l.privacyKeepAccount),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );

    if (shouldSubmit != true || _submitting) {
      reasonController.dispose();
      return;
    }
    setState(() => _submitting = true);
    try {
      final request = await AccountDeletionService.instance.submit(
        reason: reasonController.text,
      );
      if (!mounted) return;
      setState(() => _activeRequest = request);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.privacyReceivedMessage)));
    } catch (error) {
      if (mounted) _showError('${l.privacySubmitError}: $error');
    } finally {
      reasonController.dispose();
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelRequest() async {
    final request = _activeRequest;
    if (request == null) return;
    setState(() => _submitting = true);
    try {
      await AccountDeletionService.instance.cancel(request);
      if (!mounted) return;
      setState(() => _activeRequest = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.privacyCancelledMessage),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError(
          '${AppLocalizations.of(context)!.privacyCancelError}: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String t(String en, String hi) => enrollmentText(context, en, hi);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l.accountPrivacy)),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WorkspaceHeader(
                          title: t(
                            'Your account & privacy',
                            'आपका खाता और गोपनीयता',
                          ),
                          description: t(
                            'Manage your sign-in phone, understand how your information is used, or contact support.',
                            'लॉगिन फोन देखें, अपनी जानकारी के इस्तेमाल को समझें या सहायता से संपर्क करें।',
                          ),
                          icon: Icons.privacy_tip_outlined,
                        ),
                        const SizedBox(height: 24),
                        WorkspaceFormLayout(
                          showAsideOnMobile: true,
                          aside: Column(
                            children: [
                              _InfoCard(
                                icon: Icons.privacy_tip_outlined,
                                title: l.privacyYourPrivacy,
                                body: l.privacySummary,
                                actionLabel: l.privacyReadPolicy,
                                onAction: () => _open(privacyPolicyUrl),
                              ),
                              const SizedBox(height: 18),
                              _InfoCard(
                                icon: Icons.support_agent_outlined,
                                title: l.privacyHelp,
                                body: l.privacyContact(supportEmail),
                                actionLabel: l.privacyEmailSupport,
                                onAction: () => _open('mailto:$supportEmail'),
                              ),
                            ],
                          ),
                          content: Column(
                            children: [
                              _InfoCard(
                                icon: Icons.phone_android_outlined,
                                title: t('Sign-in phone', 'लॉगिन फोन'),
                                body: t(
                                  'Link a verified mobile number to sign in with an SMS code.',
                                  'SMS कोड से लॉगिन करने के लिए सत्यापित मोबाइल नंबर जोड़ें।',
                                ),
                                actionLabel: t(
                                  'Manage phone number',
                                  'फोन नंबर देखें',
                                ),
                                onAction: () => context.push('/account/phone'),
                              ),
                              const SizedBox(height: 18),
                              Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: const BorderSide(
                                    color: AppColors.outline,
                                  ),
                                ),
                                child: ExpansionTile(
                                  initiallyExpanded: _activeRequest != null,
                                  leading: const Icon(
                                    Icons.person_remove_outlined,
                                    color: AppColors.danger,
                                  ),
                                  title: Text(l.privacyDeleteTitle),
                                  subtitle: Text(
                                    t(
                                      'Request removal of your account',
                                      'अपना खाता हटाने का अनुरोध करें',
                                    ),
                                  ),
                                  childrenPadding: const EdgeInsets.all(14),
                                  children: [
                                    _deletionCard(),
                                    const SizedBox(height: 14),
                                    _InfoCard(
                                      icon: Icons.language_outlined,
                                      title: l.privacyWebRequest,
                                      body: l.privacyWebSummary,
                                      actionLabel: l.privacyOpenWeb,
                                      onAction: () => _open(accountDeletionUrl),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _deletionCard() {
    final l = AppLocalizations.of(context)!;
    final request = _activeRequest;
    final hasEmail = (AuthService.instance.user?.email ?? '').trim().isNotEmpty;
    String t(String en, String hi) => enrollmentText(context, en, hi);
    if (request != null) {
      final requested =
          '${request.requestedAt.day.toString().padLeft(2, '0')}/'
          '${request.requestedAt.month.toString().padLeft(2, '0')}/'
          '${request.requestedAt.year}';
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.mark_email_read_outlined,
              title: l.privacyReceivedTitle,
            ),
            const SizedBox(height: 12),
            Text(
              l.privacyStatusRequested(_statusLabel(request.status), requested),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              l.privacyThirtyDays,
              style: const TextStyle(color: Color(0xFF625B71), height: 1.45),
            ),
            if (request.status == 'pending' ||
                request.status == 'verifying') ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _submitting ? null : _cancelRequest,
                child: Text(l.privacyCancelRequest),
              ),
            ],
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.delete_forever_outlined,
            title: l.privacyDeleteData,
            danger: true,
          ),
          const SizedBox(height: 12),
          Text(
            hasEmail
                ? l.privacyDeleteSummary
                : t(
                  'Your account uses a phone number. Contact support to request account removal.',
                  'आपका खाता फोन नंबर से जुड़ा है। खाता हटाने के लिए सहायता से संपर्क करें।',
                ),
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
              side: const BorderSide(color: Color(0xFFB3261E)),
            ),
            onPressed:
                _submitting
                    ? null
                    : hasEmail
                    ? _requestDeletion
                    : () => _open('mailto:$supportEmail'),
            icon:
                _submitting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.delete_outline),
            label: Text(
              hasEmail
                  ? l.privacyRequestDeletion
                  : t(
                    'Contact support to delete account',
                    'खाता हटाने के लिए सहायता से संपर्क करें',
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    final l = AppLocalizations.of(context)!;
    return switch (status) {
      'verifying' => l.privacyVerifying,
      'approved' => l.privacyApproved,
      _ => l.privacyPending,
    };
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: icon, title: title),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E1F1)),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB3261E) : const Color(0xFF6750A4);
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: danger ? color : const Color(0xFF1D1B20),
            ),
          ),
        ),
      ],
    );
  }
}
