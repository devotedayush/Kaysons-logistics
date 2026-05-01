import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/route_timeline.dart';

class BidEditScreen extends StatefulWidget {
  const BidEditScreen({super.key, required this.bidId});
  final String bidId;

  @override
  State<BidEditScreen> createState() => _BidEditScreenState();
}

class _BidEditScreenState extends State<BidEditScreen> {
  final _stopController = TextEditingController();
  final List<String> _stops = [];
  String _origin = '';
  String _destination = '';
  DateTime? _closesAt;
  String? _status;

  List<Map<String, dynamic>> _transporters = [];
  final Set<String> _preferred = {};
  final Set<String> _blocked = {};

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stopController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f =
          await supabase
              .from('freights')
              .select('origin, destination_town, bid_closes_at, stops, status')
              .eq('id', widget.bidId)
              .single();
      final ts = await supabase
          .from('profiles')
          .select('id, full_name, business_name, email')
          .eq('role', 'transporter')
          .eq('status', 'approved');
      final prefs = await supabase
          .from('freight_preferred_transporters')
          .select('transporter_id')
          .eq('freight_id', widget.bidId);
      final blks = await supabase
          .from('freight_blocked_transporters')
          .select('transporter_id')
          .eq('freight_id', widget.bidId);

      if (!mounted) return;
      setState(() {
        _closesAt = DateTime.tryParse(f['bid_closes_at'] ?? '');
        _status = f['status'] as String?;
        _origin = (f['origin'] ?? '').toString();
        _destination = (f['destination_town'] ?? '').toString();
        final list = (f['stops'] as List?) ?? const [];
        _stops
          ..clear()
          ..addAll(list.map((e) => e.toString()));
        _transporters = ts.cast<Map<String, dynamic>>();
        _preferred
          ..clear()
          ..addAll(prefs.map((r) => r['transporter_id'] as String));
        _blocked
          ..clear()
          ..addAll(blks.map((r) => r['transporter_id'] as String));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
  }

  Future<void> _pickClose() async {
    final base = _closesAt ?? DateTime.now().add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: base.isBefore(DateTime.now()) ? DateTime.now() : base,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;
    setState(() {
      _closesAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void _addStop() {
    final v = _stopController.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _stops.add(v);
      _stopController.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{'stops': _stops};
      if (_status == 'bidding' && _closesAt != null) {
        update['bid_closes_at'] = _closesAt!.toIso8601String();
      }
      await supabase.from('freights').update(update).eq('id', widget.bidId);

      // Rewrite preferred + blocked — simpler than diff'ing.
      await supabase
          .from('freight_preferred_transporters')
          .delete()
          .eq('freight_id', widget.bidId);
      if (_preferred.isNotEmpty) {
        await supabase
            .from('freight_preferred_transporters')
            .insert(
              _preferred
                  .map(
                    (id) => {'freight_id': widget.bidId, 'transporter_id': id},
                  )
                  .toList(),
            );
      }
      await supabase
          .from('freight_blocked_transporters')
          .delete()
          .eq('freight_id', widget.bidId);
      if (_blocked.isNotEmpty) {
        await supabase
            .from('freight_blocked_transporters')
            .insert(
              _blocked
                  .map(
                    (id) => {'freight_id': widget.bidId, 'transporter_id': id},
                  )
                  .toList(),
            );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(DateTime d) =>
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
        title: const Text('Edit requirement'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_status == 'bidding') ...[
                    const Text(
                      'Extend bidding window',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickClose,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCAC4D0)),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 18,
                              color: Color(0xFF49454F),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _closesAt == null
                                    ? 'Pick a new close time'
                                    : 'Closes at ${_fmt(_closesAt!)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Icon(
                              Icons.edit,
                              size: 16,
                              color: Color(0xFF49454F),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF5E6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Status is $_status — bidding window can no longer be changed.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF49454F),
                          ),
                        ),
                      ),
                    ),
                  const Text(
                    'Stops in between',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RouteTimeline(
                      points: [
                        RoutePoint(label: _origin, kind: RoutePointKind.origin),
                        ..._stops.map(
                          (stop) => RoutePoint(
                            label: stop,
                            kind: RoutePointKind.stop,
                          ),
                        ),
                        RoutePoint(
                          label: _destination,
                          kind: RoutePointKind.destination,
                        ),
                      ],
                    ),
                  ),
                  if (_stops.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _stops
                                .asMap()
                                .entries
                                .map(
                                  (e) => InputChip(
                                    label: Text(e.value),
                                    onDeleted:
                                        () => setState(
                                          () => _stops.removeAt(e.key),
                                        ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: PillTextField(
                          controller: _stopController,
                          hint: 'Add a stop and tap +',
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
                  const SizedBox(height: 24),
                  if (_status == 'bidding') ...[
                    const Text(
                      'Transporter access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Green = preferred · Red = blocked · unselected = open',
                      style: TextStyle(fontSize: 11, color: Color(0xFF49454F)),
                    ),
                    const SizedBox(height: 8),
                    if (_transporters.isEmpty)
                      const Text(
                        'No approved transporters yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF49454F),
                        ),
                      )
                    else
                      ..._transporters.map(_transporterRow),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _saving ? 'Saving…' : 'Save changes',
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
    );
  }

  Widget _transporterRow(Map<String, dynamic> t) {
    final id = t['id'] as String;
    final label =
        (t['business_name'] ?? t['full_name'] ?? t['email'] ?? 'Unnamed')
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
              style: const TextStyle(fontSize: 14),
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
              size: 14,
              color: selected ? fg : const Color(0xFF49454F),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? fg : const Color(0xFF49454F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
