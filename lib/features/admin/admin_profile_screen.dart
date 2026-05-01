import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';

const _surface = Color(0xFFF8F5FB);
const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
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
              .select('full_name, email')
              .eq('id', uid)
              .maybeSingle();
      if (!mounted) return;
      _name.text = (row?['full_name'] ?? '').toString();
      _email.text =
          (row?['email'] ?? AuthService.instance.user?.email ?? '').toString();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => context.pop(),
                            ),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'Admin profile',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: _onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Logout',
                              onPressed: () async {
                                await AuthService.instance.signOut();
                                if (context.mounted) context.go('/welcome');
                              },
                              icon: const Icon(Icons.logout),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE1DAE8)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'This profile is used across the admin web console.',
                                style: TextStyle(color: _onSurfaceVariant),
                              ),
                              const SizedBox(height: 18),
                              const _FieldLabel('Full name'),
                              PillTextField(
                                controller: _name,
                                hint: 'Admin name',
                              ),
                              const SizedBox(height: 14),
                              const _FieldLabel('Email'),
                              PillTextField(
                                controller: _email,
                                hint: 'admin@example.com',
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: 220,
                                child: PrimaryButton(
                                  label: _saving ? 'Saving...' : 'Save profile',
                                  onPressed: _saving ? null : _save,
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
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _onSurfaceVariant,
        ),
      ),
    );
  }
}
