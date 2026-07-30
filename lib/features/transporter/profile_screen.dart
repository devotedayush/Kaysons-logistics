import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';

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

  final _fullName = TextEditingController();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _businessNumber = TextEditingController();
  final _gst = TextEditingController();

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
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    setState(() => _loading = true);
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
          .update({
            'full_name': _fullName.text.trim(),
            'business_name': _businessName.text.trim(),
            'phone': _phone.text.trim(),
            'business_number': _businessNumber.text.trim(),
            'gst': _gst.text.trim(),
          })
          .eq('id', uid);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'logistics_manager':
        return 'Logistics Manager';
      case 'dispatch_manager':
        return 'Dispatch Manager';
      case 'accountant':
        return 'Accountant';
      case 'transporter':
        return 'Transporter';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final name = (p?['full_name'] ?? 'Signed in').toString();
    final biz = (p?['business_name'] ?? '').toString();
    final email = (p?['email'] ?? '').toString();
    final status = (p?['status'] ?? '').toString();
    final role = _roleLabel((p?['role'] ?? '').toString());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FB),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    final wide = constraints.maxWidth >= 960;
                    final maxWidth = wide ? 1120.0 : 980.0;

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          children: [
                            _hero(
                              context,
                              compact: compact,
                              name: name,
                              biz: biz,
                              email: email,
                              status: status,
                              role: role,
                            ),
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 14 : 18,
                                  16,
                                  compact ? 14 : 18,
                                  compact ? 28 : 32,
                                ),
                                children: [
                                  if (wide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _editableCard(
                                            compact: compact,
                                            wide: wide,
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            children: [
                                              _accountCard(
                                                email: email,
                                                role: role,
                                                status: status,
                                              ),
                                              const SizedBox(height: 18),
                                              _fleetShortcutsCard(),
                                              const SizedBox(height: 18),
                                              _actionsCard(compact: compact),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    _accountCard(
                                      email: email,
                                      role: role,
                                      status: status,
                                    ),
                                    const SizedBox(height: 16),
                                    _fleetShortcutsCard(),
                                    const SizedBox(height: 16),
                                    _editableCard(compact: compact, wide: wide),
                                    const SizedBox(height: 16),
                                    _actionsCard(compact: compact),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Widget _editableCard({required bool compact, required bool wide}) {
    return _sectionCard(
      title: 'Profile details',
      subtitle:
          'Keep your contact and compliance information updated for smoother bidding and dispatch.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subheading('Business information'),
          const SizedBox(height: 12),
          _fieldGrid(
            compact: compact,
            wide: wide,
            children: [
              _field('Full name', _fullName, hint: 'Naveen Garg'),
              _field('Business name', _businessName, hint: 'Kayson Logistics'),
              _field(
                'Phone number',
                _phone,
                hint: '+91 98765 43210',
                keyboardType: TextInputType.phone,
              ),
              _field(
                'Business registration no.',
                _businessNumber,
                hint: 'BRN-1234',
              ),
              _field('GSTIN', _gst, hint: '27ABCDE1234F1Z5'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: compact ? double.infinity : 220,
            child: PrimaryButton(
              label: _saving ? 'Saving…' : 'Save changes',
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldGrid({
    required bool compact,
    required bool wide,
    required List<Widget> children,
  }) {
    if (compact) {
      return Column(children: children);
    }

    final chunks = <List<Widget>>[];
    for (var index = 0; index < children.length; index += 2) {
      chunks.add(
        children.sublist(
          index,
          index + 2 > children.length ? children.length : index + 2,
        ),
      );
    }

    return Column(
      children: [
        for (final rowChildren in chunks)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rowChildren.length; i++) ...[
                  Expanded(child: rowChildren[i]),
                  if (i != rowChildren.length - 1)
                    SizedBox(width: wide ? 16 : 12),
                ],
                if (rowChildren.length == 1) const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _accountCard({
    required String email,
    required String role,
    required String status,
  }) {
    return _sectionCard(
      title: 'Account overview',
      subtitle: 'Quick reference for your account status and sign-in details.',
      child: Column(
        children: [
          _metaRow('Email', email.isEmpty ? 'Not available' : email),
          _metaRow('Role', role.isEmpty ? 'Unknown' : role),
          _metaRow('Status', status.isEmpty ? 'Unknown' : _toTitleCase(status)),
          _metaRow('Password', 'Managed from login credentials'),
        ],
      ),
    );
  }

  Widget _fleetShortcutsCard() {
    return _sectionCard(
      title: 'Fleet setup',
      subtitle: 'Add vehicles and drivers separately for dispatch.',
      child: Row(
        children: [
          Expanded(
            child: _miniShortcut(
              icon: Icons.local_shipping_outlined,
              label: 'Vehicles',
              onTap: () => context.push('/vehicles'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniShortcut(
              icon: Icons.badge_outlined,
              label: 'Drivers',
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
      title: 'Actions',
      subtitle: 'Common account options and quick maintenance tasks.',
      child: Column(
        children: [
          _actionTile(
            icon: Icons.refresh,
            label: 'Reload profile data',
            subtitle: 'Fetch latest account information',
            onTap: _load,
          ),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Account & privacy',
            subtitle: 'Privacy policy and account deletion',
            onTap: () => context.push('/account/privacy'),
          ),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.logout,
            label: 'Logout',
            subtitle: 'Sign out and return to welcome screen',
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
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: Color(0xFF625B71),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Profile changes reflect across the mobile app and web dashboard.',
                      style: TextStyle(
                        fontSize: 12,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E1F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1B20),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B6176),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

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
              fontSize: 12,
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

  Widget _subheading(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF49454F),
        letterSpacing: 0.2,
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6176),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
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
                      fontSize: 12,
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

  Widget _hero(
    BuildContext context, {
    required bool compact,
    required String name,
    required String biz,
    required String email,
    required String status,
    required String role,
  }) {
    final heroHeight = compact ? 224.0 : 250.0;
    return Stack(
      children: [
        Container(
          height: heroHeight,
          decoration: const BoxDecoration(
            color: Color(0xFFECE6F0),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFCBC3D2),
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFE8DEF8),
              ),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: compact ? 16 : 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 60 : 68,
                height: compact ? 60 : 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _avatarLetters(name, biz, email),
                  style: TextStyle(
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: TextStyle(
                  fontSize: compact ? 24 : 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (biz.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  biz,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFF5EFF7),
                  ),
                ),
              ],
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFF5EFF7),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (role.isNotEmpty) _chip(role, solid: true),
                  if (status.isNotEmpty) _chip(_toTitleCase(status)),
                  _chip('Editable profile'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, {bool solid = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: solid ? Colors.white : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: solid ? const Color(0xFF1D1B20) : Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _toTitleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _avatarLetters(String name, String biz, String email) {
    final source = [
      name,
      biz,
      email,
    ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => 'A');
    final parts =
        source
            .replaceAll('@', ' ')
            .replaceAll('.', ' ')
            .split(' ')
            .where((part) => part.trim().isNotEmpty)
            .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return source.substring(0, 1).toUpperCase();
  }
}
