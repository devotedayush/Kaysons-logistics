import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';

const _surface = Color(0xFFF8F5FB);
const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);
const _outline = Color(0xFFCAC4D0);

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  List<Map<String, dynamic>> _drivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from('drivers')
          .select('id, name, phone, licence_number, status, updated_at')
          .eq('transporter_id', uid)
          .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _drivers = (rows as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load drivers: $e')));
    }
  }

  Future<void> _openSheet([Map<String, dynamic>? driver]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DriverFormSheet(driver: driver),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete driver?'),
            content: Text(
              '${driver['name'] ?? 'This driver'} will be removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await supabase.from('drivers').delete().eq('id', driver['id']);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Drivers',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: _onSurface,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Add driver',
                    onPressed: () => _openSheet(),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _drivers.isEmpty
                      ? _EmptyDrivers(onAdd: () => _openSheet())
                      : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          itemCount: _drivers.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder:
                              (_, i) => _DriverCard(
                                driver: _drivers[i],
                                onEdit: () => _openSheet(_drivers[i]),
                                onDelete: () => _delete(_drivers[i]),
                              ),
                        ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          _drivers.isEmpty
              ? null
              : FloatingActionButton.extended(
                onPressed: () => _openSheet(),
                icon: const Icon(Icons.add),
                label: const Text('Add driver'),
              ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> driver;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _value(String key, [String fallback = '-']) {
    final value = driver[key];
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFECE6F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.badge_outlined, color: Color(0xFF6750A4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _value('name', 'Driver name missing'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _onSurface,
                  ),
                ),
                Text(
                  '${_value('phone')} · Licence ${_value('licence_number')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDrivers extends StatelessWidget {
  const _EmptyDrivers({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 64,
              color: Color(0xFF6750A4),
            ),
            const SizedBox(height: 14),
            const Text(
              'No drivers added yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add drivers separately, then choose one during dispatch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: PrimaryButton(label: 'Add driver', onPressed: onAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverFormSheet extends StatefulWidget {
  const _DriverFormSheet({this.driver});
  final Map<String, dynamic>? driver;

  @override
  State<_DriverFormSheet> createState() => _DriverFormSheetState();
}

class _DriverFormSheetState extends State<_DriverFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _licence;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.driver ?? const <String, dynamic>{};
    _name = TextEditingController(text: (d['name'] ?? '').toString());
    _phone = TextEditingController(text: (d['phone'] ?? '').toString());
    _licence = TextEditingController(
      text: (d['licence_number'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _licence.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter driver name')));
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'transporter_id': uid,
      'name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'licence_number':
          _licence.text.trim().isEmpty ? null : _licence.text.trim(),
      'status': 'active',
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      if (widget.driver == null) {
        await supabase.from('drivers').insert(payload);
      } else {
        await supabase
            .from('drivers')
            .update(payload)
            .eq('id', widget.driver!['id']);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
                          widget.driver == null ? 'Add driver' : 'Edit driver',
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
                  _Field(
                    label: 'Driver name',
                    child: PillTextField(
                      controller: _name,
                      hint: 'Ramdeen Sharma',
                      textAlign: TextAlign.start,
                    ),
                  ),
                  _Field(
                    label: 'Driver phone',
                    child: PillTextField(
                      controller: _phone,
                      hint: '9876543210',
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  _Field(
                    label: 'Licence number',
                    child: PillTextField(
                      controller: _licence,
                      hint: 'DL-0420260011223',
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _saving ? 'Saving...' : 'Save driver',
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
