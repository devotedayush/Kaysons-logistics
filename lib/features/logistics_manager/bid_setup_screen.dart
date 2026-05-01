import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/india_city_field.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/route_timeline.dart';

class _StopDraft {
  const _StopDraft({
    required this.name,
    required this.cases,
    required this.weightKg,
  });

  final String name;
  final int cases;
  final double weightKg;

  Map<String, dynamic> toJson() => {
    'name': name,
    'cases': cases,
    'weight_kg': weightKg,
  };
}

class BidSetupScreen extends StatefulWidget {
  const BidSetupScreen({super.key});

  @override
  State<BidSetupScreen> createState() => _BidSetupScreenState();
}

class _BidSetupScreenState extends State<BidSetupScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _cases = TextEditingController();
  final _weight = TextEditingController();
  final _baseFreight = TextEditingController();
  final _internalCallingBid = TextEditingController();

  final _stopController = TextEditingController();
  final _stopCases = TextEditingController();
  final _stopWeight = TextEditingController();
  final List<_StopDraft> _stops = [];

  bool _isBid = true;
  bool _anonymous = true;
  bool _publishing = false;

  DateTime _opensAt = DateTime.now();
  DateTime _closesAt = DateTime.now().add(const Duration(hours: 2));

  List<Map<String, dynamic>> _transporters = [];
  final Set<String> _preferred = {};
  final Set<String> _blocked = {};
  String? _assignTo; // for direct-assign mode

  @override
  void initState() {
    super.initState();
    _cases.addListener(_onQuantityChanged);
    _weight.addListener(_onQuantityChanged);
    _loadTransporters();
  }

  void _onQuantityChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTransporters() async {
    try {
      final rows = await supabase
          .from('profiles')
          .select('id, full_name, business_name, email')
          .eq('role', 'transporter')
          .eq('status', 'approved');
      if (!mounted) return;
      setState(
        () => _transporters = (rows as List).cast<Map<String, dynamic>>(),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _cases.removeListener(_onQuantityChanged);
    _weight.removeListener(_onQuantityChanged);
    for (final c in [
      _from,
      _to,
      _cases,
      _weight,
      _baseFreight,
      _internalCallingBid,
      _stopController,
      _stopCases,
      _stopWeight,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime({required bool opens}) async {
    final base = opens ? _opensAt : _closesAt;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: base,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (pickedTime == null) return;
    final picked = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (opens) {
        _opensAt = picked;
        if (_closesAt.isBefore(_opensAt)) {
          _closesAt = _opensAt.add(const Duration(hours: 1));
        }
      } else {
        _closesAt = picked;
      }
    });
  }

  void _addStop() {
    final name = _stopController.text.trim();
    final cases = int.tryParse(_stopCases.text.trim()) ?? 0;
    final weight = double.tryParse(_stopWeight.text.trim()) ?? 0;
    if (name.isEmpty) return;
    setState(() {
      _stops.add(_StopDraft(name: name, cases: cases, weightKg: weight));
      _stopController.clear();
      _stopCases.clear();
      _stopWeight.clear();
    });
  }

  int get _totalCases {
    final destinationCases = int.tryParse(_cases.text.trim()) ?? 0;
    return _stops.fold<int>(destinationCases, (sum, stop) => sum + stop.cases);
  }

  double get _totalWeight {
    final destinationWeight = double.tryParse(_weight.text.trim()) ?? 0;
    return _stops.fold<double>(
      destinationWeight,
      (sum, stop) => sum + stop.weightKg,
    );
  }

  List<RoutePoint> get _routePoints => [
    RoutePoint(label: _from.text.trim(), kind: RoutePointKind.origin),
    ..._stops.map(
      (stop) => RoutePoint(
        label: stop.name,
        kind: RoutePointKind.stop,
        meta: '${stop.cases} QT · ${stop.weightKg.toStringAsFixed(0)} WT',
      ),
    ),
    RoutePoint(
      label: _to.text.trim(),
      kind: RoutePointKind.destination,
      meta:
          '${int.tryParse(_cases.text.trim()) ?? 0} QT · '
          '${(double.tryParse(_weight.text.trim()) ?? 0).toStringAsFixed(0)} WT',
    ),
  ];

  Future<void> _publish() async {
    if (_publishing) return;
    if (_from.text.trim().isEmpty || _to.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('From and To are required')));
      return;
    }
    if (!_isBid && _assignTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a transporter to assign the freight to'),
        ),
      );
      return;
    }
    if (_isBid && !_closesAt.isAfter(_opensAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Close time must be after open time')),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      final uid = AuthService.instance.user?.id;
      final payload = <String, dynamic>{
        'created_by': uid,
        'origin': _from.text.trim(),
        'destination_town': _to.text.trim(),
        'cases': _totalCases,
        'weight_kg': _totalWeight,
        'stops': _stops.map((stop) => stop.name).toList(),
        'stop_details': [
          ..._stops.map((stop) => stop.toJson()),
          {
            'name': _to.text.trim(),
            'cases': int.tryParse(_cases.text.trim()) ?? 0,
            'weight_kg': double.tryParse(_weight.text.trim()) ?? 0,
            'kind': 'destination',
          },
        ],
      };

      if (_isBid) {
        payload.addAll({
          'internal_calling_bid': double.tryParse(
            _internalCallingBid.text.trim(),
          ),
          'bid_opens_at': _opensAt.toIso8601String(),
          'bid_closes_at': _closesAt.toIso8601String(),
          'status': 'bidding',
        });
      } else {
        payload.addAll({
          'status': 'awarded',
          'winner_profile_id': _assignTo,
          'dispatched_at': DateTime.now().toIso8601String(),
        });
      }

      final freight =
          await supabase.from('freights').insert(payload).select('id').single();
      final freightId = freight['id'] as String;

      if (_isBid && _preferred.isNotEmpty) {
        await supabase
            .from('freight_preferred_transporters')
            .insert(
              _preferred
                  .map(
                    (tid) => {'freight_id': freightId, 'transporter_id': tid},
                  )
                  .toList(),
            );
      }
      if (_blocked.isNotEmpty) {
        await supabase
            .from('freight_blocked_transporters')
            .insert(
              _blocked
                  .map(
                    (tid) => {'freight_id': freightId, 'transporter_id': tid},
                  )
                  .toList(),
            );
      }
      if (!mounted) return;
      context.go('/lm/bid/$freightId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('New requirement'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              _labeled(
                'From',
                IndiaCityField(
                  controller: _from,
                  hint: 'Hoshiarpur',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              // Stops
              const SizedBox(height: 4),
              const Text(
                'Stops in between (optional)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF49454F),
                ),
              ),
              const SizedBox(height: 6),
              if (_stops.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children:
                        _stops
                            .asMap()
                            .entries
                            .map(
                              (e) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6EDFB),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.value.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${e.value.cases} QT · ${e.value.weightKg.toStringAsFixed(0)} WT',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF49454F),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed:
                                          () => setState(
                                            () => _stops.removeAt(e.key),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              Column(
                children: [
                  IndiaCityField(
                    controller: _stopController,
                    hint: 'Stop city',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: PillTextField(
                          controller: _stopCases,
                          hint: 'Stop cases QT',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.start,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PillTextField(
                          controller: _stopWeight,
                          hint: 'Stop weight WT',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.start,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addStop,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Final destination',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF49454F),
                ),
              ),
              const SizedBox(height: 6),
              IndiaCityField(
                controller: _to,
                hint: 'Destination city',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PillTextField(
                      controller: _cases,
                      hint: 'Destination cases QT',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PillTextField(
                      controller: _weight,
                      hint: 'Destination weight WT',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
              _TotalQuantityCard(cases: _totalCases, weight: _totalWeight),
              RouteTimeline(points: _routePoints),
              const SizedBox(height: 14),
              _labeled(
                'Base Freight',
                PillTextField(
                  controller: _baseFreight,
                  hint: '6500',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.start,
                ),
              ),
              const Divider(height: 28),
              SwitchListTile(
                value: _isBid,
                onChanged: (v) => setState(() => _isBid = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Open for bidding'),
                subtitle: Text(
                  _isBid
                      ? 'Transporters compete on price until the close time.'
                      : 'Assign directly to one transporter, skip the bidding window.',
                ),
              ),
              if (_isBid) ...[
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeField(
                        label: 'Opens at',
                        value: _fmtDateTime(_opensAt),
                        onTap: () => _pickDateTime(opens: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateTimeField(
                        label: 'Closes at',
                        value: _fmtDateTime(_closesAt),
                        onTap: () => _pickDateTime(opens: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _labeled(
                  'Internal calling bid (optional)',
                  PillTextField(
                    controller: _internalCallingBid,
                    hint: '15000',
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.start,
                  ),
                ),
                SwitchListTile(
                  value: _anonymous,
                  onChanged: (v) => setState(() => _anonymous = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anonymous internal bid'),
                  subtitle: const Text(
                    'Hide your calling bid from transporters',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Transporter access',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Green = preferred (notify first) · Red = blocked (can\'t see this bid) · unselected = open',
                  style: TextStyle(fontSize: 14, color: Color(0xFF49454F)),
                ),
                const SizedBox(height: 8),
                _preferBlockPicker(),
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  'Assign to transporter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _transporterPicker(multi: false),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label:
                    _publishing
                        ? 'Publishing…'
                        : (_isBid
                            ? 'Publish bid${_preferred.isEmpty ? ' (open to all)' : ' & notify ${_preferred.length} transporters'}'
                            : 'Assign & dispatch'),
                onPressed: _publishing ? null : _publish,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preferBlockPicker() {
    if (_transporters.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'No approved transporters yet.',
          style: TextStyle(fontSize: 14, color: Color(0xFF49454F)),
        ),
      );
    }
    return Column(
      children:
          _transporters.map((t) {
            final id = t['id'] as String;
            final label =
                (t['business_name'] ??
                        t['full_name'] ??
                        t['email'] ??
                        'Unnamed')
                    .toString();
            final preferred = _preferred.contains(id);
            final blocked = _blocked.contains(id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _pill(
                    label: 'Prefer',
                    icon: Icons.star_rounded,
                    selected: preferred,
                    bg: const Color(0xFFE7F6EC),
                    fg: const Color(0xFF14A33A),
                    onTap:
                        () => setState(() {
                          if (preferred) {
                            _preferred.remove(id);
                          } else {
                            _preferred.add(id);
                            _blocked.remove(id);
                          }
                        }),
                  ),
                  const SizedBox(width: 6),
                  _pill(
                    label: 'Block',
                    icon: Icons.block,
                    selected: blocked,
                    bg: const Color(0xFFFDEEEE),
                    fg: const Color(0xFFB3261E),
                    onTap:
                        () => setState(() {
                          if (blocked) {
                            _blocked.remove(id);
                          } else {
                            _blocked.add(id);
                            _preferred.remove(id);
                          }
                        }),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required bool selected,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.white,
          border: Border.all(color: selected ? fg : const Color(0xFFCAC4D0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? fg : const Color(0xFF49454F),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? fg : const Color(0xFF49454F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transporterPicker({required bool multi}) {
    if (_transporters.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'No approved transporters yet.',
          style: TextStyle(fontSize: 14, color: Color(0xFF49454F)),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          _transporters.map((t) {
            final id = t['id'] as String;
            final label =
                (t['business_name'] ??
                        t['full_name'] ??
                        t['email'] ??
                        'Unnamed')
                    .toString();
            final selected = multi ? _preferred.contains(id) : _assignTo == id;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected:
                  (v) => setState(() {
                    if (multi) {
                      if (v) {
                        _preferred.add(id);
                      } else {
                        _preferred.remove(id);
                      }
                    } else {
                      _assignTo = v ? id : null;
                    }
                  }),
            );
          }).toList(),
    );
  }

  Widget _labeled(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF49454F),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF49454F),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCAC4D0)),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: Color(0xFF49454F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 24,
                  color: Color(0xFF49454F),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalQuantityCard extends StatelessWidget {
  const _TotalQuantityCard({required this.cases, required this.weight});

  final int cases;
  final double weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB9DEC2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.functions, size: 24, color: Color(0xFF146C2E)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Total requirement',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$cases QT · ${weight.toStringAsFixed(0)} WT',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF146C2E),
            ),
          ),
        ],
      ),
    );
  }
}
