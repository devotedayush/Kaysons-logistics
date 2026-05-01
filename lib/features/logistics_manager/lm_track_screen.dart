import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/storage_photo_viewer.dart';

class LmTrackScreen extends StatelessWidget {
  const LmTrackScreen({super.key, required this.freightId});
  final String freightId;

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
        title: const Text('Delivery tracking'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: FreightsRepo.instance.streamFreight(freightId),
        builder: (context, snap) {
          final freight = snap.data;
          if (freight == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final stages = Map<String, dynamic>.from(
            freight['delivery_stages'] as Map? ?? {},
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${freight['origin']} → ${freight['destination_town']}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${freight['cases'] ?? 0} QT · ${freight['weight_kg'] ?? 0} WT · ${(freight['status'] ?? '').toString().toUpperCase()}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF49454F)),
              ),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: _winnerLabel(freight['winner_profile_id'] as String?),
                builder:
                    (context, s) => Text(
                      'Transporter: ${s.data ?? "…"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF49454F),
                      ),
                    ),
              ),
              const SizedBox(height: 14),
              _vehicleVerificationCard(context, freight, stages),
              const SizedBox(height: 24),
              const Text(
                'Delivery stages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _stageCard(
                'Dispatched',
                stages['dispatched'],
                [
                  ('Lorry number', 'lorry_number'),
                  ('Driver name', 'driver_name'),
                  ('Driver phone', 'driver_phone'),
                ],
                [
                  ('Lorry photo', 'lorry_photo_path'),
                  ('Driver photo', 'driver_photo_path'),
                  ('Driver Aadhaar', 'driver_aadhaar_photo_path'),
                ],
              ),
              _stageCard(
                'Pickup',
                stages['pickup'],
                [
                  ('Invoice number', 'invoice_number'),
                  ('Driver phone', 'driver_phone'),
                ],
                [
                  ('Invoice photo', 'invoice_photo_path'),
                  ('Site photo', 'site_photo_path'),
                ],
              ),
              _inTransitCard(context, stages['in_transit']),
              _stageCard(
                'Delivered',
                stages['delivered'],
                [
                  ('Receiver', 'receiver_name'),
                  ('Receiver phone', 'receiver_phone'),
                  ('GR number', 'gr_number'),
                  ('E-way bill', 'e_way_bill_number'),
                  ('Additional bill', 'bill_reason'),
                ],
                [
                  ('Proof of delivery', 'pod_photo_path'),
                  ('Bill photo', 'bill_photo_path'),
                  ('Site photo', 'site_photo_path'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _winnerLabel(String? uid) async {
    if (uid == null) return '—';
    final r =
        await supabase
            .from('profiles')
            .select('business_name, full_name, email')
            .eq('id', uid)
            .maybeSingle();
    if (r == null) return '—';
    return (r['business_name'] ?? r['full_name'] ?? r['email'] ?? '—')
        .toString();
  }

  Widget _vehicleVerificationCard(
    BuildContext context,
    Map<String, dynamic> freight,
    Map<String, dynamic> stages,
  ) {
    final dispatched = Map<String, dynamic>.from(
      stages['dispatched'] as Map? ?? const {},
    );
    final verification = Map<String, dynamic>.from(
      stages['vehicle_confirmation'] as Map? ?? const {},
    );
    final status = (verification['status'] ?? '').toString();
    final note = (verification['note'] ?? '').toString();
    final hasDispatch = dispatched.isNotEmpty;
    final confirmed = status == 'confirmed';
    final hasIssue = status == 'issue';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            confirmed
                ? const Color(0xFFE7F6EC)
                : hasIssue
                ? const Color(0xFFFFF1F0)
                : const Color(0xFFFFF8E1),
        border: Border.all(
          color:
              confirmed
                  ? const Color(0xFF77C28A)
                  : hasIssue
                  ? const Color(0xFFE69A95)
                  : const Color(0xFFE7C65F),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                confirmed
                    ? Icons.verified_outlined
                    : hasIssue
                    ? Icons.report_problem_outlined
                    : Icons.fact_check_outlined,
                color:
                    confirmed
                        ? const Color(0xFF146C2E)
                        : hasIssue
                        ? const Color(0xFFB3261E)
                        : const Color(0xFF7A5B00),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Vehicle verification',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasDispatch)
            const Text(
              'Waiting for transporter to submit vehicle and driver details.',
              style: TextStyle(fontSize: 12, color: Color(0xFF49454F)),
            )
          else ...[
            _kv('Vehicle', dispatched['lorry_number']),
            _kv('Driver', dispatched['driver_name']),
            _kv('Phone', dispatched['driver_phone']),
            if (status.isNotEmpty) _kv('Decision', _verificationLabel(status)),
            if (note.isNotEmpty) _kv('Note', note),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      confirmed
                          ? null
                          : () =>
                              _confirmVehicle(context, freight['id'] as String),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm arrived'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () =>
                          _raiseVehicleIssue(context, freight['id'] as String),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Wrong details'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmVehicle(BuildContext context, String freightId) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm vehicle arrived'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Optional note',
                hintText: 'Vehicle checked at gate',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (note == null) return;
    try {
      await FreightsRepo.instance.confirmVehicleArrival(
        freightId: freightId,
        note: note,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vehicle confirmed')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Confirmation failed: $e')));
    }
  }

  Future<void> _raiseVehicleIssue(
    BuildContext context,
    String freightId,
  ) async {
    final controller = TextEditingController();
    final issue = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Raise vehicle issue'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What is wrong?',
                hintText: 'Vehicle number or driver details do not match',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Raise issue'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (issue == null || issue.isEmpty) return;
    try {
      await FreightsRepo.instance.raiseVehicleIssue(
        freightId: freightId,
        issue: issue,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Issue raised')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Issue failed: $e')));
    }
  }

  String _verificationLabel(String status) {
    if (status == 'confirmed') return 'Vehicle arrived and matched';
    if (status == 'issue') return 'Issue raised';
    return status;
  }

  Widget _inTransitCard(BuildContext context, dynamic data) {
    final filled = data is Map;
    final contractors =
        filled ? (data['contractors'] as List? ?? const []) : const [];
    final lastLocation = filled ? (data['last_location'] ?? '').toString() : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCAC4D0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                filled ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color:
                    filled ? const Color(0xFF14A33A) : const Color(0xFFCAC4D0),
              ),
              const SizedBox(width: 8),
              const Text(
                'In Transit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (!filled) ...[
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 26),
              child: Text(
                'Not submitted yet',
                style: TextStyle(fontSize: 12, color: Color(0xFF49454F)),
              ),
            ),
          ] else ...[
            if (contractors.isEmpty) ...[
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 26),
                child: Text(
                  'No sub-contractors recorded',
                  style: TextStyle(fontSize: 12, color: Color(0xFF49454F)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              ...contractors.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value as Map;
                return Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contractor ${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF49454F),
                        ),
                      ),
                      _kv('Name', c['name']),
                      _kv('Phone', c['phone']),
                      _kv('Route', '${c['from'] ?? ''} → ${c['to'] ?? ''}'),
                    ],
                  ),
                );
              }),
            ],
            if (lastLocation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: _kv('Last location', lastLocation),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 8),
              child: OutlinedButton.icon(
                onPressed: () => _editTransitLocation(context, lastLocation),
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: Text(
                  lastLocation.isEmpty
                      ? 'Add location update'
                      : 'Update location',
                ),
              ),
            ),
            _proofGrid(data, [('Site photo', 'site_photo_path')]),
          ],
        ],
      ),
    );
  }

  Future<void> _editTransitLocation(
    BuildContext context,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Transit location'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Last location from driver update',
                hintText: 'e.g. Ambala bypass',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await FreightsRepo.instance.saveTransitLocation(
        freightId: freightId,
        location: value,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location updated')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location update failed: $e')));
    }
  }

  Widget _kv(String k, dynamic v) {
    final s = (v ?? '').toString();
    if (s.trim().isEmpty || s == ' → ') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              k,
              style: const TextStyle(fontSize: 12, color: Color(0xFF49454F)),
            ),
          ),
          Expanded(child: Text(s, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _stageCard(
    String title,
    dynamic data,
    List<(String, String)> fields, [
    List<(String, String)> proofs = const [],
  ]) {
    final filled = data is Map;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCAC4D0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                filled ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color:
                    filled ? const Color(0xFF14A33A) : const Color(0xFFCAC4D0),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (!filled) ...[
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 26),
              child: Text(
                'Not submitted yet',
                style: TextStyle(fontSize: 12, color: Color(0xFF49454F)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ...fields.map((f) {
              final v = data[f.$2]?.toString() ?? '';
              if (v.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        f.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF49454F),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(v, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              );
            }),
            _proofGrid(data, proofs),
          ],
        ],
      ),
    );
  }

  Widget _proofGrid(Map data, List<(String, String)> proofs) {
    final available =
        proofs
            .map((proof) => (proof.$1, (data[proof.$2] ?? '').toString()))
            .where((proof) => proof.$2.trim().isNotEmpty)
            .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            available
                .map(
                  (proof) => Builder(
                    builder:
                        (context) => ActionChip(
                          avatar: const Icon(Icons.image_outlined, size: 18),
                          label: Text(proof.$1),
                          onPressed:
                              () => showDeliveryDocumentPreview(
                                context: context,
                                title: proof.$1,
                                path: proof.$2,
                              ),
                        ),
                  ),
                )
                .toList(),
      ),
    );
  }
}
