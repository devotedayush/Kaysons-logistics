import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../auth/enrollment_strings.dart';

class TransporterProfileScreen extends StatefulWidget {
  const TransporterProfileScreen({super.key});

  @override
  State<TransporterProfileScreen> createState() =>
      _TransporterProfileScreenState();
}

class _TransporterProfileScreenState extends State<TransporterProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _detailsLoaded = false;

  final _fullName = TextEditingController();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _businessNumber = TextEditingController();
  final _gst = TextEditingController();
  final _contactEmail = TextEditingController();
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  String? _bankId, _chequePath, _chequeName;
  Uint8List? _chequeBytes;
  String? _chequeExtension;
  String t(String en, String hi) => enrollmentText(context, en, hi);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _businessName,
      _phone,
      _businessNumber,
      _gst,
      _contactEmail,
      _holder,
      _account,
      _ifsc,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    setState(() {
      _loading = true;
      _detailsLoaded = false;
    });
    try {
      final row =
          await supabase
              .from('profiles')
              .select(
                'full_name, business_name, email, role, status, phone, business_number, gst',
              )
              .eq('id', uid)
              .maybeSingle();
      if (!mounted) return;
      _profile = row;
      _fullName.text = (row?['full_name'] ?? '').toString();
      _businessName.text = (row?['business_name'] ?? '').toString();
      _phone.text = (row?['phone'] ?? '').toString();
      _businessNumber.text = (row?['business_number'] ?? '').toString();
      _gst.text = (row?['gst'] ?? '').toString();
      _contactEmail.text = (row?['email'] ?? '').toString();
      _phone.text = AuthService.instance.user?.phone ?? '';
      final banks = await supabase
          .from('bank_accounts')
          .select('id,holder_name,account_number,ifsc,cheque_url')
          .eq('profile_id', uid)
          .order('created_at')
          .limit(1);
      if (!mounted) return;
      if (banks.isNotEmpty) {
        final bank = banks.first;
        _bankId = bank['id'].toString();
        _holder.text = (bank['holder_name'] ?? '').toString();
        _account.text = (bank['account_number'] ?? '').toString();
        _ifsc.text = (bank['ifsc'] ?? '').toString();
        _chequePath = bank['cheque_url'] as String?;
      }
      _detailsLoaded = row != null;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Profile details could not be loaded. Try reloading.',
                'प्रोफ़ाइल जानकारी लोड नहीं हुई। फिर लोड करें।',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null || _saving || !_detailsLoaded) return;
    final hasBank =
        [
          _holder.text,
          _account.text,
          _ifsc.text,
        ].any((v) => v.trim().isNotEmpty) ||
        _chequeBytes != null;
    if (!isValidContactEmail(_contactEmail.text) ||
        (hasBank &&
            !isValidBankDetails(_holder.text, _account.text, _ifsc.text))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Use a valid contact email. For bank details enter holder, 9–18 digit account number and valid IFSC.',
              'सही संपर्क ईमेल भरें। बैंक के लिए धारक, 9–18 अंकों का खाता नंबर और सही IFSC भरें।',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await supabase
          .from('profiles')
          .update({
            'full_name': _fullName.text.trim(),
            'business_name': _businessName.text.trim(),
            'email':
                _contactEmail.text.trim().isEmpty
                    ? null
                    : _contactEmail.text.trim(),
            'business_number': _businessNumber.text.trim(),
            'gst': _gst.text.trim(),
          })
          .eq('id', uid)
          .select('id')
          .single();
      if (hasBank) {
        if (_chequeBytes != null) {
          final extension = _chequeExtension!;
          final path =
              '$uid/registration/bank-cheque/${DateTime.now().microsecondsSinceEpoch}.$extension';
          await supabase.storage
              .from('delivery-documents')
              .uploadBinary(
                path,
                _chequeBytes!,
                fileOptions: FileOptions(
                  contentType:
                      extension == 'png'
                          ? 'image/png'
                          : extension == 'webp'
                          ? 'image/webp'
                          : 'image/jpeg',
                ),
              );
          // Retain the uploaded reference if the row save fails; retry reuses it.
          _chequePath = path;
          _chequeBytes = null;
        }
        final data = {
          'holder_name': _holder.text.trim(),
          'account_number': _account.text.trim(),
          'ifsc': _ifsc.text.trim().toUpperCase(),
          'cheque_url': _chequePath,
        };
        if (_bankId == null) {
          final existing = await supabase
              .from('bank_accounts')
              .select('id')
              .eq('profile_id', uid)
              .order('created_at')
              .limit(1);
          if (existing.isNotEmpty) _bankId = existing.first['id'].toString();
        }
        if (_bankId != null) {
          await supabase
              .from('bank_accounts')
              .update(data)
              .eq('id', _bankId!)
              .eq('profile_id', uid)
              .select('id')
              .single();
        } else {
          final bank =
              await supabase
                  .from('bank_accounts')
                  .insert({...data, 'profile_id': uid})
                  .select('id')
                  .single();
          _bankId = bank['id'].toString();
        }
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.tpProfileUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tpUpdateFailed('$e')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickCheque() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty || !mounted) return;
      final file = picked.files.single;
      final extension = file.extension?.toLowerCase();
      if (file.bytes == null ||
          file.bytes!.isEmpty ||
          file.size > 5 * 1024 * 1024 ||
          !['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Choose a JPG, PNG or WebP image up to 5 MB.',
                '5 MB तक की JPG, PNG या WebP तस्वीर चुनें।',
              ),
            ),
          ),
        );
        return;
      }
      setState(() {
        _chequeBytes = file.bytes;
        _chequeName = file.name;
        _chequeExtension = extension;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('Could not open the image picker.', 'तस्वीर चयन नहीं खुल सका।'),
            ),
          ),
        );
      }
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return AppLocalizations.of(context)!.tpAdmin;
      case 'logistics_manager':
        return AppLocalizations.of(context)!.tpLogisticsManager;
      case 'dispatch_manager':
        return AppLocalizations.of(context)!.tpDispatchManager;
      case 'accountant':
        return AppLocalizations.of(context)!.accountant;
      case 'transporter':
        return AppLocalizations.of(context)!.transporter;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final name =
        (p?['full_name'] ?? AppLocalizations.of(context)!.tpSignedIn)
            .toString();
    final email = (p?['email'] ?? '').toString();
    final status = (p?['status'] ?? '').toString();
    final role = _roleLabel((p?['role'] ?? '').toString());
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.profile)),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WorkspaceHeader(
                            title: name,
                            description: t(
                              'Keep your contact details up to date. Fill business and bank sections when you are ready.',
                              'अपनी संपर्क जानकारी अपडेट रखें। व्यवसाय और बैंक की जानकारी जब तैयार हों तब भरें।',
                            ),
                            icon: Icons.person_outline,
                            summary: Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                StatusBadge(
                                  label: role,
                                  tone: WorkspaceTone.info,
                                ),
                                StatusBadge(
                                  label: _toTitleCase(status),
                                  tone:
                                      status == 'approved'
                                          ? WorkspaceTone.success
                                          : WorkspaceTone.warning,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (status == 'pending') ...[
                            GuidanceCard(
                              title: t(
                                'Awaiting account approval',
                                'खाते की स्वीकृति की प्रतीक्षा',
                              ),
                              message: t(
                                'Your registration is submitted. An administrator must approve it before you can use bids and trips.',
                                'आपका पंजीकरण जमा है। बोलियाँ और सफ़र इस्तेमाल करने से पहले प्रशासक की स्वीकृति आवश्यक है।',
                              ),
                              tone: WorkspaceTone.warning,
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (!_detailsLoaded) ...[
                            GuidanceCard(
                              title: t(
                                'Profile could not be loaded',
                                'प्रोफ़ाइल नहीं खुल सकी',
                              ),
                              message: t(
                                'Reload your saved details before making changes.',
                                'बदलाव करने से पहले सहेजी जानकारी फिर खोलें।',
                              ),
                              tone: WorkspaceTone.warning,
                              action: OutlinedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: Text(
                                  t('Reload profile', 'प्रोफ़ाइल फिर खोलें'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 820;
                              final details = _editableCard(
                                compact: !wide,
                                wide: wide,
                              );
                              final account = Column(
                                children: [
                                  _accountCard(
                                    email: email,
                                    role: role,
                                    status: status,
                                  ),
                                  const SizedBox(height: 18),
                                  if (status == 'approved') ...[
                                    _fleetShortcutsCard(),
                                    const SizedBox(height: 18),
                                  ],
                                  _actionsCard(compact: !wide),
                                ],
                              );
                              return wide
                                  ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: details),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 2, child: account),
                                    ],
                                  )
                                  : Column(
                                    children: [
                                      details,
                                      const SizedBox(height: 18),
                                      account,
                                    ],
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _editableCard({
    required bool compact,
    required bool wide,
  }) => WorkspaceSection(
    title: t('Your contact details', 'आपकी संपर्क जानकारी'),
    description: t(
      'Save after making changes. Optional sections can be completed later.',
      'बदलाव के बाद सहेजें। वैकल्पिक जानकारी बाद में भर सकते हैं।',
    ),
    children: [
      _field(
        AppLocalizations.of(context)!.tpFullName,
        _fullName,
        hint: t('Your full name', 'आपका पूरा नाम'),
      ),
      GuidanceCard(
        title: t('Verified sign-in phone', 'सत्यापित लॉगिन फोन'),
        message:
            _phone.text.isEmpty
                ? t('No verified phone linked', 'सत्यापित फोन नहीं जुड़ा')
                : _phone.text,
        icon: Icons.verified_user_outlined,
        action: TextButton(
          onPressed: () => context.push('/account/phone'),
          child: Text(t('Change verified phone', 'सत्यापित फोन बदलें')),
        ),
      ),
      const SizedBox(height: 18),
      _field(
        t('Contact email (optional)', 'संपर्क ईमेल (वैकल्पिक)'),
        _contactEmail,
        keyboardType: TextInputType.emailAddress,
      ),
      const Divider(),
      Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 12),
          title: Text(
            t('Business details (optional)', 'व्यवसाय की जानकारी (वैकल्पिक)'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            _businessName.text.isEmpty
                ? t(
                  'Business name, registration number & GSTIN',
                  'व्यवसाय का नाम, पंजीकरण नंबर और GSTIN',
                )
                : _businessName.text,
          ),
          children: [
            _field(
              AppLocalizations.of(context)!.tpBusinessName,
              _businessName,
              hint: t('Your business name', 'आपके व्यवसाय का नाम'),
            ),
            _field(
              AppLocalizations.of(context)!.tpBusinessRegistration,
              _businessNumber,
            ),
            _field('GSTIN', _gst, hint: '27ABCDE1234F1Z5'),
          ],
        ),
      ),
      const Divider(),
      Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 12),
          title: Text(
            t('Bank details (optional)', 'बैंक जानकारी (वैकल्पिक)'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            t(
              'Add these when you are ready to receive payments.',
              'भुगतान पाने के लिए जब तैयार हों, तब यह जानकारी भरें।',
            ),
          ),
          children: [
            GuidanceCard(
              title: t(
                'Complete the three bank fields together',
                'बैंक के तीनों खाने एक साथ भरें',
              ),
              message: t(
                'Account holder, account number and IFSC are needed if you add a bank account. A cheque image is optional.',
                'बैंक खाता जोड़ने पर खाताधारक, खाता नंबर और IFSC आवश्यक हैं। चेक की तस्वीर वैकल्पिक है।',
              ),
            ),
            const SizedBox(height: 16),
            _field(t('Account holder', 'खाताधारक'), _holder),
            _field(
              t('Account number', 'खाता नंबर'),
              _account,
              keyboardType: TextInputType.number,
            ),
            _field('IFSC', _ifsc),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickCheque,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _chequeName ??
                    (_chequePath != null
                        ? t('Replace cheque image', 'चेक की तस्वीर बदलें')
                        : t(
                          'Upload cheque image (optional)',
                          'चेक की तस्वीर अपलोड करें (वैकल्पिक)',
                        )),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          label:
              _saving
                  ? AppLocalizations.of(context)!.tpSavingEllipsis
                  : AppLocalizations.of(context)!.tpSaveChanges,
          onPressed: _saving || !_detailsLoaded ? null : _save,
        ),
      ),
    ],
  );

  Widget _accountCard({
    required String email,
    required String role,
    required String status,
  }) {
    return _sectionCard(
      title: AppLocalizations.of(context)!.tpAccountOverview,
      subtitle: AppLocalizations.of(context)!.tpAccountOverviewHint,
      child: Column(
        children: [
          _metaRow(
            AppLocalizations.of(context)!.email,
            email.isEmpty
                ? AppLocalizations.of(context)!.tpNotAvailable
                : email,
          ),
          _metaRow(
            AppLocalizations.of(context)!.tpRole,
            role.isEmpty ? AppLocalizations.of(context)!.tpUnknown : role,
          ),
          _metaRow(
            AppLocalizations.of(context)!.tpStatus,
            status.isEmpty
                ? AppLocalizations.of(context)!.tpUnknown
                : _toTitleCase(status),
          ),
          _metaRow(
            t('Sign-in method', 'लॉगिन विधि'),
            AuthService.instance.user?.phoneConfirmedAt != null
                ? t('Verified phone and SMS code', 'सत्यापित फोन और SMS कोड')
                : t(
                  'Linked account credentials',
                  'जुड़े खाते की लॉगिन जानकारी',
                ),
          ),
        ],
      ),
    );
  }

  Widget _fleetShortcutsCard() {
    return _sectionCard(
      title: AppLocalizations.of(context)!.tpFleetSetup,
      subtitle: AppLocalizations.of(context)!.tpFleetSetupHint,
      child: Row(
        children: [
          Expanded(
            child: _miniShortcut(
              icon: Icons.local_shipping_outlined,
              label: AppLocalizations.of(context)!.tpVehicles,
              onTap: () => context.push('/vehicles'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniShortcut(
              icon: Icons.badge_outlined,
              label: AppLocalizations.of(context)!.tpDrivers,
              onTap: () => context.push('/drivers'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniShortcut({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6750A4)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1B20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard({required bool compact}) {
    return _sectionCard(
      title: AppLocalizations.of(context)!.tpActions,
      subtitle: AppLocalizations.of(context)!.tpActionsHint,
      child: Column(
        children: [
          _actionTile(
            icon: Icons.refresh,
            label: AppLocalizations.of(context)!.tpReloadProfile,
            subtitle: AppLocalizations.of(context)!.tpFetchLatest,
            onTap: _load,
          ),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.privacy_tip_outlined,
            label: AppLocalizations.of(context)!.accountPrivacy,
            subtitle: AppLocalizations.of(context)!.tpPrivacyDeletion,
            onTap: () => context.push('/account/privacy'),
          ),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.logout,
            label: AppLocalizations.of(context)!.logout,
            subtitle: AppLocalizations.of(context)!.tpSignOutHint,
            onTap: () async {
              await AuthService.instance.signOut();
              if (!mounted) return;
              context.go('/welcome');
            },
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5FB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: Color(0xFF625B71),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.tpProfileSyncHint,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF6B6176),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) =>
      WorkspaceSection(title: title, description: subtitle, children: [child]);

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF49454F),
            ),
          ),
          const SizedBox(height: 6),
          PillTextField(
            controller: controller,
            hint: hint,
            textAlign: TextAlign.start,
            keyboardType: keyboardType,
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6176),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1D1B20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFECE6F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF625B71)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1B20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6176),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF625B71)),
          ],
        ),
      ),
    );
  }

  String _toTitleCase(String value) {
    if (value.isEmpty) return value;
    final l = AppLocalizations.of(context)!;
    switch (value.toLowerCase()) {
      case 'active':
        return l.tpActive;
      case 'approved':
        return l.tpApproved;
      case 'pending':
        return l.tpPending;
      case 'rejected':
        return l.tpRejected;
      case 'suspended':
        return l.tpSuspended;
    }
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
