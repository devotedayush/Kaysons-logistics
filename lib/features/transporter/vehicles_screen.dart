import '../../core/widgets/workspace_widgets.dart';
import 'widgets/transporter_workspace.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../l10n/app_localizations.dart';

const _surface = Color(0xFFF8F5FB);
const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);
const _outline = Color(0xFFCAC4D0);

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key, this.loadData});
  final Future<List<Map<String, dynamic>>> Function()? loadData;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;
  String _query = '';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.loadData != null) {
      setState(() {
        _loading = true;
        _failed = false;
      });
      try {
        final rows = await widget.loadData!();
        if (mounted) {
          setState(() {
            _vehicles = rows;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loading = false;
            _failed = true;
          });
        }
      }
      return;
    }

    final uid = AuthService.instance.user?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await supabase
          .from('vehicles')
          .select(
            'id, registration_number, vehicle_type, capacity_qt, capacity_weight_kg, rc_number, insurance_number, status, updated_at',
          )
          .eq('profile_id', uid)
          .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _vehicles = (rows as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tpCouldNotLoadVehicles('$e'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteVehicle(Map<String, dynamic> vehicle) async {
    final label =
        (vehicle['registration_number'] ??
                AppLocalizations.of(context)!.tpThisVehicle)
            .toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.tpDeleteVehicleQuestion),
            content: Text(
              AppLocalizations.of(context)!.tpVehicleWillBeRemoved(label),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.tpCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context)!.tpDelete),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from('vehicles').delete().eq('id', vehicle['id']);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.tpVehicleDeleted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tpDeleteFailed('$e')),
        ),
      );
    }
  }

  Future<void> _openVehicleSheet([Map<String, dynamic>? vehicle]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _VehicleFormSheet(vehicle: vehicle),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final visible =
        _vehicles
            .where(
              (row) =>
                  '${row['registration_number'] ?? ''} ${row['vehicle_type'] ?? ''}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
            )
            .toList();
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(tpText(context, 'Back', 'वापस')),
                ),
              ),
              WorkspaceHeader(
                title: l.tpVehicles,
                description: tpText(
                  context,
                  'Keep your vehicles ready. Add or update details before assigning a trip.',
                  'अपने वाहन तैयार रखें। यात्रा से पहले जानकारी जोड़ें या बदलें।',
                ),
                icon: Icons.local_shipping_outlined,
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                  onPressed: () => _openVehicleSheet(),
                  icon: const Icon(Icons.add),
                  label: Text(l.tpAddVehicle),
                ),
              ),
              const SizedBox(height: 20),
              TransporterSearch(
                label: tpText(
                  context,
                  'Search vehicle number or type',
                  'वाहन नंबर या प्रकार से खोजें',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_failed)
                WorkspaceEmptyState(
                  title: tpText(
                    context,
                    'Could not load vehicles',
                    'जानकारी लोड नहीं हुई',
                  ),
                  message: tpText(
                    context,
                    'Check your connection and try again.',
                    'इंटरनेट जाँचकर फिर प्रयास करें।',
                  ),
                  icon: Icons.wifi_off,
                  action: FilledButton(
                    onPressed: _load,
                    child: Text(
                      tpText(context, 'Try again', 'फिर प्रयास करें'),
                    ),
                  ),
                )
              else if (_vehicles.isEmpty)
                _EmptyVehicles(onAdd: () => _openVehicleSheet())
              else if (visible.isEmpty)
                WorkspaceEmptyState(
                  title: tpText(
                    context,
                    'No matching vehicles',
                    'कोई मेल नहीं मिला',
                  ),
                  message: tpText(
                    context,
                    'Try another name or number in the search above.',
                    'ऊपर खोज में दूसरा नाम या नंबर भरें।',
                  ),
                  icon: Icons.search_off,
                )
              else ...[
                SectionHeading(
                  title: tpText(
                    context,
                    '${visible.length} vehicles',
                    '${visible.length} वाहन',
                  ),
                  description: tpText(
                    context,
                    'Choose Edit to update details. Remove is in the more menu.',
                    'जानकारी बदलने के लिए संपादित करें चुनें। हटाना अधिक मेनू में है।',
                  ),
                ),
                const SizedBox(height: 12),
                TransporterCardGrid(
                  children: [
                    for (final row in visible)
                      _VehicleCard(
                        vehicle: row,
                        onEdit: () => _openVehicleSheet(row),
                        onDelete: () => _deleteVehicle(row),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _value(String key, [String fallback = '-']) {
    final value = vehicle[key];
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final capacity = [
      if (_value('capacity_qt').trim() != '-') l.tpCases(_value('capacity_qt')),
      if (_value('capacity_weight_kg').trim() != '-')
        '${_value('capacity_weight_kg')} MT',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFECE6F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF6750A4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _value('registration_number', l.tpVehicleNumberMissing),
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        _value('vehicle_type', l.tpTruck),
                        if (capacity.isNotEmpty) capacity,
                      ].join(' · '),
                      style: const TextStyle(color: _onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(value: 'edit', child: Text(l.tpEdit)),
                      PopupMenuItem(value: 'delete', child: Text(l.tpDelete)),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.tpEditVehicle),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DetailChip(label: l.tpRc, value: _value('rc_number')),
              _DetailChip(
                label: l.tpInsurance,
                value: _value('insurance_number'),
              ),
              _DetailChip(
                label: l.tpStatus,
                value:
                    _value('status', 'active') == 'active'
                        ? l.tpActive
                        : tpText(context, 'Inactive', 'निष्क्रिय'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EDFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyVehicles extends StatelessWidget {
  const _EmptyVehicles({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Color(0xFF6750A4),
            ),
            const SizedBox(height: 14),
            Text(
              l.tpNoVehicles,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.tpAddVehiclesHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: PrimaryButton(label: l.tpAddVehicle, onPressed: onAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleFormSheet extends StatefulWidget {
  const _VehicleFormSheet({this.vehicle});
  final Map<String, dynamic>? vehicle;

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  late final TextEditingController _number;
  late final TextEditingController _type;
  late final TextEditingController _capacityQt;
  late final TextEditingController _capacityWeight;
  late final TextEditingController _rc;
  late final TextEditingController _insurance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle ?? const <String, dynamic>{};
    _number = TextEditingController(
      text: (vehicle['registration_number'] ?? '').toString(),
    );
    _type = TextEditingController(
      text: (vehicle['vehicle_type'] ?? '').toString(),
    );
    _capacityQt = TextEditingController(
      text: (vehicle['capacity_qt'] ?? '').toString(),
    );
    _capacityWeight = TextEditingController(
      text: (vehicle['capacity_weight_kg'] ?? '').toString(),
    );
    _rc = TextEditingController(text: (vehicle['rc_number'] ?? '').toString());
    _insurance = TextEditingController(
      text: (vehicle['insurance_number'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _number,
      _type,
      _capacityQt,
      _capacityWeight,
      _rc,
      _insurance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _doubleOrNull(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _save() async {
    if (_saving) return;
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    if (_number.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tpEnterVehicleNumber),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final payload = {
      'profile_id': uid,
      'transporter_id': uid,
      'registration_number': _number.text.trim(),
      'number': _number.text.trim(),
      'vehicle_type': _type.text.trim().isEmpty ? null : _type.text.trim(),
      'type': _type.text.trim().isEmpty ? null : _type.text.trim(),
      'capacity_qt': _doubleOrNull(_capacityQt.text),
      'capacity_weight_kg': _doubleOrNull(_capacityWeight.text),
      'capacity_kg': _doubleOrNull(_capacityWeight.text),
      'rc_number': _rc.text.trim().isEmpty ? null : _rc.text.trim(),
      'insurance_number':
          _insurance.text.trim().isEmpty ? null : _insurance.text.trim(),
      'status': 'active',
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      if (widget.vehicle == null) {
        await supabase.from('vehicles').insert(payload);
      } else {
        await supabase
            .from('vehicles')
            .update(payload)
            .eq('id', widget.vehicle!['id']);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tpSaveFailed('$e')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, bottom + 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.vehicle == null
                              ? l.tpAddVehicle
                              : l.tpEditVehicle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: _onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GuidanceCard(
                    title: tpText(
                      context,
                      'Start with the essential details',
                      'पहले ज़रूरी जानकारी भरें',
                    ),
                    message: tpText(
                      context,
                      'Review the details before saving. You can edit them later.',
                      'सहेजने से पहले जानकारी जाँचें। बाद में इसे बदल सकते हैं।',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: l.tpVehicleNumber,
                    child: PillTextField(
                      controller: _number,
                      hint: 'PB10AB1234',
                      textAlign: TextAlign.start,
                    ),
                  ),
                  _Field(
                    label: l.tpVehicleType,
                    child: PillTextField(
                      controller: _type,
                      hint: l.tpTruckTrailer,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  TransporterCardGrid(
                    breakpoint: 560,
                    children: [
                      _Field(
                        label: l.tpCapacityCases,
                        child: PillTextField(
                          controller: _capacityQt,
                          hint: '160',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.start,
                        ),
                      ),
                      _Field(
                        label: l.tpMetricMt,
                        child: PillTextField(
                          controller: _capacityWeight,
                          hint: '28',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  ),
                  Material(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        tpText(
                          context,
                          'Registration & insurance (optional)',
                          'रजिस्ट्रेशन और बीमा (वैकल्पिक)',
                        ),
                      ),
                      children: [
                        _Field(
                          label: l.tpRcNumber,
                          child: PillTextField(
                            controller: _rc,
                            hint: 'RC-2026-4455',
                            textAlign: TextAlign.start,
                          ),
                        ),
                        _Field(
                          label: l.tpInsuranceNumber,
                          child: PillTextField(
                            controller: _insurance,
                            hint: 'INS-2026-44321',
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _saving ? l.tpSaving : l.tpSaveVehicle,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
