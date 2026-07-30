import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/legal_links.dart';
import '../../core/supabase/account_deletion_service.dart';

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
      if (mounted) _showError('Could not load deletion status: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      _showError('Could not open the webpage.');
    }
  }

  Future<void> _requestDeletion() async {
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
                          const Text(
                            'Request account deletion?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'We will verify the request using your registered email. Your account and associated personal data will be deleted or de-identified, except records we must retain for legal, accounting, fraud-prevention or active contractual reasons.',
                            style: TextStyle(height: 1.45),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: reasonController,
                            maxLength: 1000,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Reason (optional)',
                              hintText: 'Tell us anything we should know',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: confirmed,
                            onChanged:
                                (value) => setSheetState(
                                  () => confirmed = value ?? false,
                                ),
                            title: const Text(
                              'I understand this requests permanent deletion of my account and associated data.',
                              style: TextStyle(fontSize: 14, height: 1.35),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.pop(false),
                                  child: const Text('Keep account'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFB3261E),
                                  ),
                                  onPressed:
                                      confirmed
                                          ? () => context.pop(true)
                                          : null,
                                  child: const Text('Submit request'),
                                ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Deletion request received. We will verify it by email.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showError('Could not submit request: $error');
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
        const SnackBar(content: Text('Deletion request cancelled.')),
      );
    } catch (error) {
      if (mounted) _showError('Could not cancel request: $error');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5FB),
        title: const Text('Account & privacy'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _InfoCard(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Your privacy',
                        body:
                            'See what Kaysons Logistics collects, why it is used, how long it is kept, and how to contact us.',
                        actionLabel: 'Read privacy policy',
                        onAction: () => _open(privacyPolicyUrl),
                      ),
                      const SizedBox(height: 14),
                      _deletionCard(),
                      const SizedBox(height: 14),
                      _InfoCard(
                        icon: Icons.language_outlined,
                        title: 'Request from the web',
                        body:
                            'You can also request deletion after uninstalling the app. The public form does not require a login.',
                        actionLabel: 'Open deletion webpage',
                        onAction: () => _open(accountDeletionUrl),
                      ),
                      const SizedBox(height: 14),
                      _InfoCard(
                        icon: Icons.support_agent_outlined,
                        title: 'Need help?',
                        body:
                            'Contact $supportEmail for privacy, access, correction or account questions.',
                        actionLabel: 'Email support',
                        onAction: () => _open('mailto:$supportEmail'),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _deletionCard() {
    final request = _activeRequest;
    if (request != null) {
      final requested =
          '${request.requestedAt.day.toString().padLeft(2, '0')}/'
          '${request.requestedAt.month.toString().padLeft(2, '0')}/'
          '${request.requestedAt.year}';
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              icon: Icons.mark_email_read_outlined,
              title: 'Deletion request received',
            ),
            const SizedBox(height: 12),
            Text(
              'Status: ${_statusLabel(request.status)}\nRequested: $requested',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'We normally complete a verified request within 30 days. We may contact your registered email to confirm identity or explain records that must be retained.',
              style: TextStyle(color: Color(0xFF625B71), height: 1.45),
            ),
            if (request.status == 'pending' ||
                request.status == 'verifying') ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _submitting ? null : _cancelRequest,
                child: const Text('Cancel deletion request'),
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
          const _CardHeader(
            icon: Icons.delete_forever_outlined,
            title: 'Delete account and data',
            danger: true,
          ),
          const SizedBox(height: 12),
          const Text(
            'Submit a permanent deletion request for your Kaysons Logistics account and associated personal data. Verification protects your account from unauthorized requests.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
              side: const BorderSide(color: Color(0xFFB3261E)),
            ),
            onPressed: _submitting ? null : _requestDeletion,
            icon:
                _submitting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.delete_outline),
            label: const Text('Request account deletion'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'verifying' => 'Identity verification',
      'approved' => 'Approved for deletion',
      _ => 'Pending review',
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
          TextButton(onPressed: onAction, child: Text(actionLabel)),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E1F1)),
      ),
      child: child,
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
