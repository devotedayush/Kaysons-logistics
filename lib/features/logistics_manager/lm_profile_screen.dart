import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../auth/enrollment_strings.dart';

const _surface = Color(0xFFF8F5FB);
const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class LmProfileScreen extends StatefulWidget {
  const LmProfileScreen({super.key});

  @override
  State<LmProfileScreen> createState() => _LmProfileScreenState();
}

class LmTransporterDirectoryScreen extends StatelessWidget {
  const LmTransporterDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.opsTransporters),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: _TransporterDirectory(),
      ),
    );
  }
}

class LmVehicleDirectoryScreen extends StatelessWidget {
  const LmVehicleDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.opsVehicles),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: _VehicleDirectory(),
      ),
    );
  }
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
    final rawPhone = _phone.text.trim();
    if (rawPhone.isNotEmpty) {
      final normalizedPhone = normalizeIndianPhone(rawPhone);
      if (normalizedPhone == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.opsInvalidPhone),
          ),
        );
        return;
      }
      _phone.text = normalizedPhone;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.opsProfileUpdated),
        ),
      );
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
    final l = AppLocalizations.of(context)!;
    String t(String en, String hi) => enrollmentText(context, en, hi);
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(l.opsManagerProfile),
        actions: [
          IconButton(
            tooltip: l.opsRefresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                          title:
                              _name.text.isEmpty
                                  ? l.opsManagerProfile
                                  : _name.text,
                          description: t(
                            'Update your work contact and coverage area. Account access is managed by your administrator.',
                            'अपना काम का संपर्क और कार्यक्षेत्र अपडेट करें। खाते की पहुँच प्रशासक तय करते हैं।',
                          ),
                          icon: Icons.badge_outlined,
                          summary: Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              StatusBadge(
                                label: _roleLabel(_role),
                                tone: WorkspaceTone.info,
                              ),
                              StatusBadge(
                                label: _title(_status),
                                tone: WorkspaceTone.success,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        WorkspaceFormLayout(
                          showAsideOnMobile: true,
                          aside: WorkspaceSection(
                            title: l.opsAccount,
                            children: [
                              _meta(l.opsEmail, _email.isEmpty ? '—' : _email),
                              _meta(l.opsRole, _roleLabel(_role)),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => context.push('/account/phone'),
                                icon: const Icon(Icons.phone_android_outlined),
                                label: Text(
                                  t('Manage sign-in phone', 'लॉगिन फोन देखें'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed:
                                    () => context.push('/account/privacy'),
                                icon: const Icon(Icons.privacy_tip_outlined),
                                label: Text(l.accountPrivacy),
                              ),
                            ],
                          ),
                          content: WorkspaceSection(
                            title: l.opsWorkDetails,
                            description: t(
                              'These details help the team contact you and assign work in your area.',
                              'यह जानकारी टीम को आपसे संपर्क करने और आपके क्षेत्र में काम देने में मदद करती है।',
                            ),
                            children: [
                              _field(
                                l.opsName,
                                _name,
                                hint: t('Your full name', 'आपका पूरा नाम'),
                              ),
                              _field(
                                l.opsPhoneNumber,
                                _phone,
                                hint: '+91 98765 43210',
                                keyboardType: TextInputType.phone,
                              ),
                              _field(
                                l.opsAreaCovered,
                                _coverageArea,
                                hint: 'Delhi NCR, Haryana, Punjab',
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: PrimaryButton(
                                  label:
                                      _saving ? l.opsSaving : l.opsSaveChanges,
                                  onPressed: _saving ? null : _save,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_role == 'logistics_manager' ||
                            _role == 'admin') ...[
                          const SizedBox(height: 24),
                          WorkspaceSection(
                            title: t('Team directories', 'टीम की सूचियाँ'),
                            description: t(
                              'Find transporter contacts or check vehicle information. These lists are read-only.',
                              'ट्रांसपोर्टर का संपर्क या वाहन की जानकारी देखें। ये सूचियाँ केवल देखने के लिए हैं।',
                            ),
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed:
                                        () => context.push('/lm/transporters'),
                                    icon: const Icon(Icons.business_outlined),
                                    label: Text(l.opsAllTransporters),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed:
                                        () => context.push('/lm/vehicles'),
                                    icon: const Icon(
                                      Icons.local_shipping_outlined,
                                    ),
                                    label: Text(l.opsAllVehicles),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
              fontSize: 14,
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
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
  Widget build(BuildContext context) =>
      const _SearchableDirectory(vehicles: false);
}

class _VehicleDirectory extends StatelessWidget {
  const _VehicleDirectory();
  @override
  Widget build(BuildContext context) =>
      const _SearchableDirectory(vehicles: true);
}

class _SearchableDirectory extends StatefulWidget {
  const _SearchableDirectory({required this.vehicles});
  final bool vehicles;
  @override
  State<_SearchableDirectory> createState() => _SearchableDirectoryState();
}

class _SearchableDirectoryState extends State<_SearchableDirectory> {
  late Future<List<Map<String, dynamic>>> _rows = _fetch();
  String _query = '';
  Future<List<Map<String, dynamic>>> _fetch() =>
      widget.vehicles
          ? _fetchVehiclesWithOwners()
          : supabase
              .from('profiles')
              .select('id, full_name, business_name, email, phone, status')
              .eq('role', 'transporter')
              .order('business_name', ascending: true)
              .then((rows) => (rows as List).cast<Map<String, dynamic>>());
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String t(String en, String hi) => enrollmentText(context, en, hi);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkspaceHeader(
              title: widget.vehicles ? l.opsAllVehicles : l.opsAllTransporters,
              description:
                  widget.vehicles
                      ? t(
                        'Search a vehicle number or transporter. Check capacity and ownership before planning a trip.',
                        'वाहन नंबर या ट्रांसपोर्टर खोजें। सफ़र की योजना से पहले क्षमता और मालिक देखें।',
                      )
                      : t(
                        'Search by name, business or phone to find the right transporter.',
                        'सही ट्रांसपोर्टर ढूँढने के लिए नाम, व्यवसाय या फोन से खोजें।',
                      ),
              icon:
                  widget.vehicles
                      ? Icons.local_shipping_outlined
                      : Icons.business_outlined,
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText:
                    widget.vehicles
                        ? t(
                          'Search vehicle number or transporter',
                          'वाहन नंबर या ट्रांसपोर्टर खोजें',
                        )
                        : t(
                          'Search name, business or phone',
                          'नाम, व्यवसाय या फोन खोजें',
                        ),
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _rows,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snap.hasError) {
                  return WorkspaceEmptyState(
                    title: t('List could not be loaded', 'सूची नहीं खुल सकी'),
                    message: t(
                      'Try again to load the latest records.',
                      'नई जानकारी देखने के लिए फिर प्रयास करें।',
                    ),
                    action: OutlinedButton.icon(
                      onPressed: () => setState(() => _rows = _fetch()),
                      icon: const Icon(Icons.refresh),
                      label: Text(l.opsRefresh),
                    ),
                  );
                }
                final rows =
                    (snap.data ?? [])
                        .where(
                          (r) =>
                              r.values.join(' ').toLowerCase().contains(_query),
                        )
                        .toList();
                if (rows.isEmpty) {
                  return WorkspaceEmptyState(
                    title: t('No matching records', 'कोई जानकारी नहीं मिली'),
                    message: t(
                      'Try another name or number.',
                      'दूसरा नाम या नंबर खोजें।',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t('${rows.length} records', '${rows.length} रिकॉर्ड'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 740 ? 2 : 1;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 14) /
                            columns;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children:
                              rows.map((row) {
                                final title =
                                    widget.vehicles
                                        ? (row['registration_number'] ?? '—')
                                            .toString()
                                        : (row['business_name'] ??
                                                row['full_name'] ??
                                                row['email'] ??
                                                '—')
                                            .toString();
                                final values =
                                    widget.vehicles
                                        ? [
                                          row['owner_label'],
                                          row['vehicle_type'],
                                          if (row['capacity_qt'] != null)
                                            '${row['capacity_qt']} ${t('cases', 'केस')}',
                                          if (row['capacity_weight_kg'] != null)
                                            '${row['capacity_weight_kg']} MT',
                                          _title(
                                            (row['status'] ?? '').toString(),
                                          ),
                                        ]
                                        : [
                                          row['full_name'],
                                          row['phone'],
                                          row['email'],
                                          _title(
                                            (row['status'] ?? '').toString(),
                                          ),
                                        ];
                                return SizedBox(
                                  width: width,
                                  child: WorkspaceSection(
                                    title: title,
                                    children: [
                                      for (final v in values.where(
                                        (v) =>
                                            v != null &&
                                            v.toString().trim().isNotEmpty,
                                      ))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: SelectableText(v.toString()),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
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

String _roleLabel(String role) {
  if (role == 'logistics_manager') return 'Logistics Manager';
  if (role == 'dispatch_manager') return 'Dispatch Manager';
  if (role == 'accountant') return 'Accountant';
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
