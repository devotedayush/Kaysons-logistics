import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../auth/enrollment_strings.dart';
import '../../l10n/app_localizations.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  String? _role;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _email = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    try {
      final row =
          await supabase
              .from('profiles')
              .select('full_name, email, role')
              .eq('id', uid)
              .maybeSingle();
      if (!mounted) return;
      _name.text = (row?['full_name'] ?? '').toString();
      _email.text =
          (row?['email'] ?? AuthService.instance.user?.email ?? '').toString();
      _role = row?['role']?.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await supabase
          .from('profiles')
          .update({'full_name': _name.text.trim()})
          .eq('id', uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.adminProfileUpdated),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.adminUpdateFailed}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String t(String en, String hi) => enrollmentText(context, en, hi);
    final profileLabel = switch (_role) {
      'accountant' => l.adminAccountantProfile,
      'admin' => l.adminAdminProfile,
      _ => l.profile,
    };
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(profileLabel)),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: WorkspaceFormLayout(
                  showAsideOnMobile: true,
                  aside: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WorkspaceHeader(
                        title: profileLabel,
                        description: t(
                          'Manage your name and check your account details.',
                          'अपना नाम अपडेट करें और खाते की जानकारी देखें।',
                        ),
                        icon: Icons.person_outline,
                        summary: StatusBadge(
                          label:
                              _role == 'accountant'
                                  ? l.accountant
                                  : l.adminConsole,
                          tone: WorkspaceTone.info,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GuidanceCard(
                        title: t(
                          'Need to change sign-in details?',
                          'लॉगिन की जानकारी बदलनी है?',
                        ),
                        message: t(
                          'Your account role is managed by an administrator. Use phone settings to change a verified sign-in number.',
                          'खाते की भूमिका प्रशासक तय करते हैं। सत्यापित लॉगिन नंबर बदलने के लिए फोन सेटिंग इस्तेमाल करें।',
                        ),
                        action: OutlinedButton.icon(
                          onPressed: () => context.push('/account/phone'),
                          icon: const Icon(Icons.phone_outlined),
                          label: Text(
                            t('Manage phone number', 'फोन नंबर देखें'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: WorkspaceSection(
                    title: l.adminAccountDetails,
                    description: t(
                      'Update your name, then save. Your sign-in email is shown for reference.',
                      'अपना नाम बदलकर सहेजें। लॉगिन ईमेल जानकारी के लिए दिखाया गया है।',
                    ),
                    children: [
                      Text(
                        l.adminFullName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      PillTextField(controller: _name, hint: l.adminNameHint),
                      const SizedBox(height: 22),
                      Text(
                        l.email,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _email,
                        readOnly: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          helperText: t(
                            'Sign-in email · managed with your account',
                            'लॉगिन ईमेल · खाते के साथ तय होता है',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: _saving ? l.adminSaving : l.adminSaveProfile,
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Divider(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.push('/account/privacy'),
                            icon: const Icon(Icons.privacy_tip_outlined),
                            label: Text(l.accountPrivacy),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await AuthService.instance.signOut();
                              if (context.mounted) context.go('/welcome');
                            },
                            icon: const Icon(Icons.logout),
                            label: Text(l.logout),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
