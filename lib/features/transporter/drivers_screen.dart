import '../../core/widgets/workspace_widgets.dart';
import 'widgets/transporter_workspace.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../l10n/app_localizations.dart';

const _surface = Color(0xFFF8F5FB);
const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);
const _outline = Color(0xFFCAC4D0);

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key, this.loadData});
  final Future<List<Map<String, dynamic>>> Function()? loadData;

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  List<Map<String, dynamic>> _drivers = [];
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
            _drivers = rows;
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
      setState(() {
        _loading = false;
        _failed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tpCouldNotLoadDrivers('$e'),
          ),
        ),
      );
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
            title: Text(AppLocalizations.of(context)!.tpDeleteDriverQuestion),
            content: Text(
              AppLocalizations.of(context)!.tpDriverWillBeRemoved(
                '${driver['name'] ?? AppLocalizations.of(context)!.tpThisDriver}',
              ),
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
    await supabase.from('drivers').delete().eq('id', driver['id']);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final visible =
        _drivers
            .where(
              (row) => '${row['name'] ?? ''} ${row['phone'] ?? ''}'
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
                title: l.tpDrivers,
                description: tpText(
                  context,
                  'Your drivers, easy to find. Add or update details before assigning a trip.',
                  'अपने ड्राइवर आसानी से खोजें। यात्रा से पहले जानकारी जोड़ें या बदलें।',
                ),
                icon: Icons.badge_outlined,
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                  onPressed: () => _openSheet(),
                  icon: const Icon(Icons.add),
                  label: Text(l.tpAddDriver),
                ),
              ),
              const SizedBox(height: 20),
              TransporterSearch(
                label: tpText(
                  context,
                  'Search drivers by name or phone',
                  'नाम या फोन से ड्राइवर खोजें',
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
                    'Could not load drivers',
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
              else if (_drivers.isEmpty)
                _EmptyDrivers(onAdd: () => _openSheet())
              else if (visible.isEmpty)
                WorkspaceEmptyState(
                  title: tpText(
                    context,
                    'No matching drivers',
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
                    '${visible.length} drivers',
                    '${visible.length} ड्राइवर',
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
                      _DriverCard(
                        driver: row,
                        onEdit: () => _openSheet(row),
                        onDelete: () => _delete(row),
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
    final l = AppLocalizations.of(context)!;
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
                  _value('name', l.tpDriverNameMissing),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _onSurface,
                  ),
                ),
                Text(
                  l.tpPhoneLicence(_value('phone'), _value('licence_number')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.tpEdit),
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
    final l = AppLocalizations.of(context)!;
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
            Text(
              l.tpNoDrivers,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.tpAddDriversHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: PrimaryButton(label: l.tpAddDriver, onPressed: onAdd),
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
  String? _error;

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
    final l = AppLocalizations.of(context)!;
    final uid = AuthService.instance.user?.id;
    if (uid == null) {
      setState(
        () =>
            _error = tpText(
              context,
              'Your session has expired. Sign in again to save the driver.',
              'आपका सत्र समाप्त हो गया है। ड्राइवर सहेजने के लिए फिर लॉग इन करें।',
            ),
      );
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l.tpEnterDriverName);
      return;
    }
    final phone = _phone.text.trim();
    if (phone.isNotEmpty && !isValidIndianPhone(phone)) {
      setState(() => _error = l.tpEnterValidPhone);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = {
      'transporter_id': uid,
      'name': _name.text.trim(),
      'phone': phone.isEmpty ? null : normalizeIndianPhone(phone),
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
      setState(() => _error = l.tpSaveFailed('$e'));
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
                          widget.driver == null
                              ? l.tpAddDriver
                              : l.tpEditDriver,
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
                    label: l.tpDriverName,
                    child: PillTextField(
                      controller: _name,
                      hint: 'Ramdeen Sharma',
                      textAlign: TextAlign.start,
                    ),
                  ),
                  _Field(
                    label: l.tpDriverPhone,
                    child: PillTextField(
                      controller: _phone,
                      hint: '9876543210',
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        tpText(
                          context,
                          'Licence details (optional)',
                          'लाइसेंस की जानकारी (वैकल्पिक)',
                        ),
                      ),
                      children: [
                        _Field(
                          label: l.tpLicenceNumber,
                          child: PillTextField(
                            controller: _licence,
                            hint: 'DL-0420260011223',
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        key: const ValueKey('driver-save-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  PrimaryButton(
                    label: _saving ? l.tpSaving : l.tpSaveDriver,
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
