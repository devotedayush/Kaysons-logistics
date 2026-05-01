import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';

const _surface = Color(0xFFF8F5FB);
const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);
const _outline = Color(0xFFE4DCEB);

class LmProfileScreen extends StatefulWidget {
  const LmProfileScreen({super.key});

  @override
  State<LmProfileScreen> createState() => _LmProfileScreenState();
}

class _LmProfileScreenState extends State<LmProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  String _email = '';
  String _status = '';
  String _role = '';
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _coverageArea = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _coverageArea.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      Map<String, dynamic>? row;
      try {
        row =
            await supabase
                .from('profiles')
                .select('full_name, email, role, status, phone, coverage_area')
                .eq('id', uid)
                .maybeSingle();
      } catch (_) {
        row =
            await supabase
                .from('profiles')
                .select('full_name, email, role, status, phone')
                .eq('id', uid)
                .maybeSingle();
      }
      if (!mounted) return;
      _name.text = (row?['full_name'] ?? '').toString();
      _phone.text = (row?['phone'] ?? '').toString();
      _coverageArea.text = (row?['coverage_area'] ?? '').toString();
      _email = (row?['email'] ?? '').toString();
      _status = (row?['status'] ?? '').toString();
      _role = (row?['role'] ?? '').toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      try {
        await supabase
            .from('profiles')
            .update({
              'full_name': _name.text.trim(),
              'phone': _phone.text.trim(),
              'coverage_area': _coverageArea.text.trim(),
            })
            .eq('id', uid);
      } catch (_) {
        await supabase
            .from('profiles')
            .update({
              'full_name': _name.text.trim(),
              'phone': _phone.text.trim(),
            })
            .eq('id', uid);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => context.pop(),
                          ),
                          const Expanded(
                            child: Text(
                              'Manager profile',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: _onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _card(
                        title: 'Work details',
                        subtitle:
                            'Only manager identity and operating area are needed here.',
                        child: Column(
                          children: [
                            _field('Name', _name, hint: 'Logistics manager'),
                            _field(
                              'Phone number',
                              _phone,
                              hint: '+91 98765 43210',
                              keyboardType: TextInputType.phone,
                            ),
                            _field(
                              'Area covered',
                              _coverageArea,
                              hint: 'Delhi NCR, Haryana, Punjab',
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 220,
                                child: PrimaryButton(
                                  label: _saving ? 'Saving...' : 'Save changes',
                                  onPressed: _saving ? null : _save,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _card(
                        title: 'Account',
                        subtitle:
                            'Business, GST and vehicle ownership stay with transporters.',
                        child: Column(
                          children: [
                            _meta('Email', _email.isEmpty ? '-' : _email),
                            _meta('Role', _roleLabel(_role)),
                            _meta('Status', _title(_status)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _card(
                        title: 'All transporters',
                        subtitle:
                            'Read-only list for assigning bids and checking responsibility.',
                        child: const _TransporterDirectory(),
                      ),
                      const SizedBox(height: 14),
                      _card(
                        title: 'All vehicles',
                        subtitle:
                            'Vehicles are added by transporters. Managers verify what arrives.',
                        child: const _VehicleDirectory(),
                      ),
                    ],
                  ),
                ),
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
              fontWeight: FontWeight.w700,
              color: _onSurfaceVariant,
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

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: _onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransporterDirectory extends StatelessWidget {
  const _TransporterDirectory();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('profiles')
          .select('id, full_name, business_name, email, phone, status')
          .eq('role', 'transporter')
          .order('business_name', ascending: true)
          .then((rows) => (rows as List).cast<Map<String, dynamic>>()),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return const Text(
            'No transporters found.',
            style: TextStyle(color: _onSurfaceVariant),
          );
        }
        return Column(
          children:
              rows
                  .take(12)
                  .map(
                    (row) => _DirectoryTile(
                      icon: Icons.business_outlined,
                      title:
                          (row['business_name'] ??
                                  row['full_name'] ??
                                  row['email'] ??
                                  'Transporter')
                              .toString(),
                      subtitle: [
                        (row['phone'] ?? '').toString(),
                        _title((row['status'] ?? '').toString()),
                      ].where((v) => v.trim().isNotEmpty).join(' · '),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _VehicleDirectory extends StatelessWidget {
  const _VehicleDirectory();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchVehiclesWithOwners(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text(
            'Vehicle list is unavailable until manager read access is applied.',
            style: TextStyle(color: Colors.red.shade700),
          );
        }
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return const Text(
            'No vehicles found.',
            style: TextStyle(color: _onSurfaceVariant),
          );
        }
        return Column(
          children:
              rows.take(12).map((row) {
                final owner = (row['owner_label'] ?? 'Transporter').toString();
                final capacity = [
                  if ((row['capacity_qt'] ?? '').toString().isNotEmpty)
                    '${row['capacity_qt']} QT',
                  if ((row['capacity_weight_kg'] ?? '').toString().isNotEmpty)
                    '${row['capacity_weight_kg']} WT',
                ].join(' · ');
                return _DirectoryTile(
                  icon: Icons.local_shipping_outlined,
                  title: (row['registration_number'] ?? 'Vehicle').toString(),
                  subtitle: [
                    owner,
                    (row['vehicle_type'] ?? '').toString(),
                    capacity,
                    _title((row['status'] ?? '').toString()),
                  ].where((v) => v.trim().isNotEmpty).join(' · '),
                );
              }).toList(),
        );
      },
    );
  }
}

Future<List<Map<String, dynamic>>> _fetchVehiclesWithOwners() async {
  final vehicleRows = await supabase
      .from('vehicles')
      .select(
        'profile_id, registration_number, vehicle_type, capacity_qt, capacity_weight_kg, rc_number, insurance_number, status, updated_at',
      )
      .order('updated_at', ascending: false);
  final vehicles = (vehicleRows as List).cast<Map<String, dynamic>>();
  final ownerIds =
      vehicles
          .map((row) => (row['profile_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
  if (ownerIds.isEmpty) return vehicles;
  final profileRows = await supabase
      .from('profiles')
      .select('id, business_name, full_name, email')
      .inFilter('id', ownerIds);
  final ownerLabels = {
    for (final row in (profileRows as List))
      row['id'].toString():
          (row['business_name'] ??
                  row['full_name'] ??
                  row['email'] ??
                  'Transporter')
              .toString(),
  };
  return [
    for (final vehicle in vehicles)
      {
        ...vehicle,
        'owner_label': ownerLabels[vehicle['profile_id']] ?? 'Transporter',
      },
  ];
}

class _DirectoryTile extends StatelessWidget {
  const _DirectoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6750A4)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String role) {
  if (role == 'logistics_manager') return 'Logistics Manager';
  if (role == 'admin') return 'Admin';
  if (role == 'transporter') return 'Transporter';
  return role.isEmpty ? 'Unknown' : _title(role);
}

String _title(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
