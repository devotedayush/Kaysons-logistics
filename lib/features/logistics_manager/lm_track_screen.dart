import 'widgets/operational_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/widgets/storage_photo_viewer.dart';
import '../../core/widgets/logistics_artwork.dart';
import '../delivery/delivery_workflow_panel.dart';

class LmTrackScreen extends StatelessWidget {
  const LmTrackScreen({
    super.key,
    required this.freightId,
    this.dispatchManagerMode = false,
    this.accountantMode = false,
  });
  final String freightId;
  final bool dispatchManagerMode;
  final bool accountantMode;

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
        title: Text(AppLocalizations.of(context)!.opsDeliveryTracking),
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
          final destinations = _trackingDestinations(freight);
          final receivingWorkflow = freight['delivery_workflow_version'] == 1;
          return OperationalListView(
            padding: const EdgeInsets.all(16),
            children: [
              WorkspaceHeader(
                title: operationalCopy(
                  context,
                  'Check delivery progress',
                  'डिलीवरी प्रगति जाँचें',
                ),
                description: operationalCopy(
                  context,
                  'Confirm the vehicle, follow the journey and review each customer’s delivery proof.',
                  'वाहन की पुष्टि करें, यात्रा देखें और हर ग्राहक के डिलीवरी प्रमाण जाँचें।',
                ),
                icon: Icons.route_outlined,
                summary: StatusBadge(
                  label:
                      freight['ack_status'] == 'received'
                          ? operationalCopy(
                            context,
                            'All receiving checks complete',
                            'प्राप्ति जाँच पूरी',
                          )
                          : operationalCopy(
                            context,
                            'Receiving checks still pending',
                            'प्राप्ति जाँच बाकी',
                          ),
                  tone:
                      freight['ack_status'] == 'received'
                          ? WorkspaceTone.success
                          : WorkspaceTone.warning,
                ),
              ),
              const SizedBox(height: 16),
              LogisticsArtwork(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${freight['origin']} → ${freight['destination_town']}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${freight['cases'] ?? 0} Cases · ${formatMetricTons(freight['weight_kg'])} MT · ${(freight['status'] ?? '').toString().toUpperCase()}',
                      ),
                    ],
                  ),
                ),
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
              if (!accountantMode)
                _vehicleVerificationCard(context, freight, stages),
              const SizedBox(height: 10),
              if (!receivingWorkflow && !accountantMode)
                _podTimingCard(context, freight, stages),
              const SizedBox(height: 24),
              OperationalStep(
                '1',
                operationalCopy(
                  context,
                  'Truck and pickup checks',
                  'ट्रक और पिकअप जाँच',
                ),
                operationalCopy(
                  context,
                  'Open a stage to compare the submitted details with the actual vehicle and documents.',
                  'जमा किए विवरण की वाहन और दस्तावेज़ से तुलना करने के लिए चरण खोलें।',
                ),
              ),
              Text(
                AppLocalizations.of(context)!.opsDeliveryStages,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              if (!accountantMode)
                _stageCard(
                  context,
                  AppLocalizations.of(context)!.opsDispatched,
                  freight['id'] as String,
                  'dispatched',
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
              if (!accountantMode)
                _stageCard(
                  context,
                  AppLocalizations.of(context)!.opsPickup,
                  freight['id'] as String,
                  'pickup',
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
              OperationalStep(
                '2',
                operationalCopy(
                  context,
                  'Customer delivery and proof',
                  'ग्राहक डिलीवरी और प्रमाण',
                ),
                operationalCopy(
                  context,
                  'Review every customer separately. Resolve any shortfall before accepting proof.',
                  'हर ग्राहक की अलग जाँच करें। प्रमाण स्वीकार करने से पहले कमी ठीक करें।',
                ),
              ),
              DeliveryWorkflowPanel(
                key: ValueKey('workflow-$freightId'),
                freight: freight,
                office: true,
                readOnly: dispatchManagerMode,
                canEditPlan: !accountantMode,
                canApproveExpenses:
                    !accountantMode ||
                    const ['locked', 'completed'].contains(freight['status']),
              ),
              if (!receivingWorkflow && !accountantMode)
                _inTransitCard(
                  context,
                  freight['id'] as String,
                  stages['in_transit'],
                ),
              if (!receivingWorkflow &&
                  !accountantMode &&
                  destinations.length > 1)
                _multiStopDeliveryCard(context, destinations, stages)
              else if (!receivingWorkflow && !accountantMode)
                _stageCard(
                  context,
                  AppLocalizations.of(context)!.opsDelivered,
                  freight['id'] as String,
                  'delivered',
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
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.opsVehicleVerification,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasDispatch)
            Text(
              AppLocalizations.of(context)!.opsWaitingVehicle,
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
                  label: Text(AppLocalizations.of(context)!.opsConfirmArrived),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () =>
                          _raiseVehicleIssue(context, freight['id'] as String),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: Text(AppLocalizations.of(context)!.opsWrongDetails),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _podTimingCard(
    BuildContext context,
    Map<String, dynamic> freight,
    Map<String, dynamic> stages,
  ) {
    final destinations = _trackingDestinations(freight);
    if (destinations.length > 1) {
      return _multiStopPodCard(context, destinations, stages);
    }
    final delivered = Map<String, dynamic>.from(
      stages['delivered'] as Map? ?? const {},
    );
    final dispatchedAt = DateTime.tryParse(
      (freight['dispatched_at'] ?? '').toString(),
    );
    final podSubmittedAt = DateTime.tryParse(
      (delivered['submitted_at'] ?? '').toString(),
    );
    final podPath = (delivered['pod_photo_path'] ?? '').toString();
    final delayDays =
        dispatchedAt == null || podSubmittedAt == null
            ? null
            : _calendarDayDifference(dispatchedAt, podSubmittedAt);
    final missingOverdue =
        dispatchedAt != null &&
        podSubmittedAt == null &&
        _calendarDayDifference(dispatchedAt, DateTime.now()) > 3;
    final late = (delayDays ?? 0) > 3;

    final color =
        late || missingOverdue
            ? const Color(0xFFFFF1F0)
            : const Color(0xFFE7F6EC);
    final border =
        late || missingOverdue
            ? const Color(0xFFE69A95)
            : const Color(0xFF77C28A);
    final icon =
        late || missingOverdue
            ? Icons.warning_amber_outlined
            : Icons.fact_check_outlined;
    final title =
        late
            ? 'Late POD review'
            : missingOverdue
            ? 'POD overdue'
            : 'POD timing';
    final detail =
        late
            ? 'POD was submitted ${delayDays}d after dispatch. Review possible delayed dispatch or freight clubbing.'
            : missingOverdue
            ? 'No POD has been submitted after the 3-day SLA.'
            : podSubmittedAt == null
            ? 'POD has not been submitted yet.'
            : 'POD was submitted within the 3-day SLA.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color:
                    late || missingOverdue
                        ? const Color(0xFFB3261E)
                        : const Color(0xFF146C2E),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(fontSize: 12, color: Color(0xFF49454F)),
          ),
          const SizedBox(height: 6),
          _kv('Dispatch', _shortDateTime(dispatchedAt)),
          _kv('POD time', _shortDateTime(podSubmittedAt)),
          if (podPath.isNotEmpty) _kv('POD proof', 'Uploaded'),
        ],
      ),
    );
  }

  Widget _multiStopPodCard(
    BuildContext context,
    List<String> destinations,
    Map<String, dynamic> stages,
  ) {
    final l = AppLocalizations.of(context)!;
    final saved = stages['delivered_stops'] as List? ?? const [];
    final delivered = saved.whereType<Map>().length;
    final withProof =
        saved
            .whereType<Map>()
            .where(
              (stop) =>
                  (stop['pod_photo_path'] ?? '').toString().trim().isNotEmpty,
            )
            .length;
    final complete = delivered == destinations.length;
    return Card(
      color:
          complete && withProof == destinations.length
              ? const Color(0xFFE7F6EC)
              : const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.opsDeliveryPodStatus,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(l.opsDestinationsDelivered(delivered, destinations.length)),
            Text(l.opsDeliveryProofsUploaded(withProof, destinations.length)),
          ],
        ),
      ),
    );
  }

  Widget _multiStopDeliveryCard(
    BuildContext context,
    List<String> destinations,
    Map<String, dynamic> stages,
  ) {
    final l = AppLocalizations.of(context)!;
    final saved = stages['delivered_stops'] as List? ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, destination) in destinations.indexed)
          Builder(
            builder: (context) {
              Map? stop;
              for (final item in saved) {
                if (item is Map && item['stop_index'] == index) {
                  stop = item;
                  break;
                }
              }
              final data = stop;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$destination · ${data == null ? l.adminPending : l.opsDelivered}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (data != null) ...[
                        _kv(
                          l.opsReceiverName,
                          (data['receiver_name'] ?? '').toString(),
                        ),
                        _kv(
                          l.opsPhone,
                          (data['receiver_phone'] ?? '').toString(),
                        ),
                        _kv(
                          l.opsGoodsInvoiceChallans,
                          _trackingNumbers(data['invoice_numbers']),
                        ),
                        _kv(l.opsGrBilty, _trackingNumbers(data['gr_numbers'])),
                        _kv(
                          l.opsEwayBills,
                          _trackingNumbers(data['e_way_bill_numbers']),
                        ),
                        if ((data['pod_photo_path'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.image_outlined, size: 18),
                            label: Text(l.opsViewDeliveryProof),
                            onPressed:
                                () => showDeliveryDocumentPreview(
                                  context: context,
                                  title:
                                      '${l.opsProofOfDelivery} · $destination',
                                  path: data['pod_photo_path'].toString(),
                                ),
                          )
                        else
                          Text(l.opsDeliveryProofPending),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _confirmVehicle(BuildContext context, String freightId) async {
    final note = await showDialog<String>(
      context: context,
      builder:
          (_) => _TextEntryDialog(
            title: AppLocalizations.of(context)!.opsConfirmVehicleArrived,
            label: AppLocalizations.of(context)!.opsOptionalNote,
            hint: 'Vehicle checked at gate',
            actionLabel: AppLocalizations.of(context)!.opsConfirm,
          ),
    );
    if (note == null) return;
    try {
      await FreightsRepo.instance.confirmVehicleArrival(
        freightId: freightId,
        note: note,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.opsVehicleConfirmed),
        ),
      );
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
    final issue = await showDialog<String>(
      context: context,
      builder:
          (_) => _TextEntryDialog(
            title: AppLocalizations.of(context)!.opsRaiseVehicleIssue,
            label: AppLocalizations.of(context)!.opsWhatIsWrong,
            hint: 'Vehicle number or driver details do not match',
            actionLabel: AppLocalizations.of(context)!.opsRaiseIssue,
            maxLines: 3,
          ),
    );
    if (issue == null || issue.isEmpty) return;
    try {
      await FreightsRepo.instance.raiseVehicleIssue(
        freightId: freightId,
        issue: issue,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.opsIssueRaised)),
      );
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

  int _calendarDayDifference(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }

  String _shortDateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  Widget _inTransitCard(BuildContext context, String freightId, dynamic data) {
    final filled = data is Map;
    final stageData = Map<String, dynamic>.from(data is Map ? data : const {});
    final contractors =
        filled ? (stageData['contractors'] as List? ?? const []) : const [];
    final lastLocation =
        filled ? (stageData['last_location'] ?? '').toString() : '';
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
                AppLocalizations.of(context)!.opsInTransit,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed:
                    () => _editStage(
                      context,
                      freightId,
                      'in_transit',
                      AppLocalizations.of(context)!.opsInTransit,
                      stageData,
                      dispatchManagerMode: dispatchManagerMode,
                    ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  filled
                      ? AppLocalizations.of(context)!.opsEdit
                      : AppLocalizations.of(context)!.opsAdd,
                ),
              ),
            ],
          ),
          if (!filled) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: 26),
              child: Text(
                AppLocalizations.of(context)!.opsNotSubmittedYet,
                style: TextStyle(fontSize: 12, color: Color(0xFF49454F)),
              ),
            ),
          ] else ...[
            if (contractors.isEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.only(left: 26),
                child: Text(
                  AppLocalizations.of(context)!.opsNoSubContractors,
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
            _proofGrid(stageData, [('Site photo', 'site_photo_path')]),
          ],
        ],
      ),
    );
  }

  Future<void> _editTransitLocation(
    BuildContext context,
    String current,
  ) async {
    final value = await showDialog<String>(
      context: context,
      builder:
          (_) => _TextEntryDialog(
            title: 'Transit location',
            label: AppLocalizations.of(context)!.opsLastDriverLocation,
            hint: 'e.g. Ambala bypass',
            actionLabel: 'Save',
            initialValue: current,
          ),
    );
    if (value == null || value.isEmpty) return;
    try {
      await FreightsRepo.instance.saveTransitLocation(
        freightId: freightId,
        location: value,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.opsLocationUpdated),
        ),
      );
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
    BuildContext context,
    String title,
    String freightId,
    String stage,
    dynamic data,
    List<(String, String)> fields, [
    List<(String, String)> proofs = const [],
  ]) {
    final filled = data is Map;
    final stageData = Map<String, dynamic>.from(data is Map ? data : const {});
    final visibleFields = _visibleDisplayFields(fields);
    final visibleProofs = _visibleDisplayProofs(proofs);
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
              const Spacer(),
              TextButton.icon(
                onPressed:
                    () => _editStage(
                      context,
                      freightId,
                      stage,
                      title,
                      stageData,
                      dispatchManagerMode: dispatchManagerMode,
                    ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  filled
                      ? AppLocalizations.of(context)!.opsEdit
                      : AppLocalizations.of(context)!.opsAdd,
                ),
              ),
            ],
          ),
          if (!filled) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: 26),
              child: Text(
                AppLocalizations.of(context)!.opsNotSubmittedYet,
                style: TextStyle(fontSize: 12, color: Color(0xFF49454F)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ...visibleFields.map((f) {
              final v = stageData[f.$2]?.toString() ?? '';
              if (v.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final label = _localizedStageFieldLabel(
                      context,
                      _StageTextField(f.$1, f.$2),
                    );
                    final labelWidget = Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF49454F),
                      ),
                    );
                    final valueWidget = Text(
                      v,
                      style: const TextStyle(fontSize: 13),
                    );
                    if (constraints.maxWidth < 300) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [labelWidget, valueWidget],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 140, child: labelWidget),
                        Expanded(child: valueWidget),
                      ],
                    );
                  },
                ),
              );
            }),
            _proofGrid(stageData, visibleProofs),
          ],
        ],
      ),
    );
  }

  Future<void> _editStage(
    BuildContext context,
    String freightId,
    String stage,
    String title,
    Map<String, dynamic> initialData, {
    bool? dispatchManagerMode,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => _StageEditDialog(
            freightId: freightId,
            stage: stage,
            title: title,
            initialData: initialData,
            dispatchManagerMode:
                dispatchManagerMode ?? this.dispatchManagerMode,
          ),
    );
    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.opsDeliveryCheckSaved),
      ),
    );
  }

  List<(String, String)> _visibleDisplayFields(List<(String, String)> fields) {
    if (!dispatchManagerMode) return fields;
    return fields
        .where((field) => !_isRestrictedDocumentKey(field.$2))
        .toList();
  }

  List<(String, String)> _visibleDisplayProofs(List<(String, String)> proofs) {
    if (!dispatchManagerMode) return proofs;
    return proofs
        .where((proof) => !_isRestrictedDocumentKey(proof.$2))
        .toList();
  }

  bool _isRestrictedDocumentKey(String key) => const {
    'invoice_number',
    'invoice_photo_path',
    'gr_bilty_number',
    'gr_number',
    'e_way_bill_number',
    'bill_reason',
    'bill_photo_path',
  }.contains(key);

  Widget _proofGrid(Map data, List<(String, String)> proofs) {
    final available =
        proofs
            .map(
              (proof) => (
                proof.$1,
                proof.$2,
                (data[proof.$2] ?? '').toString(),
              ),
            )
            .where((proof) => proof.$3.trim().isNotEmpty)
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
                          label: Text(
                            _localizedProofLabel(
                              context,
                              _StageProofField(proof.$1, proof.$2, ''),
                            ),
                          ),
                          onPressed:
                              () => showDeliveryDocumentPreview(
                                context: context,
                                title: _localizedProofLabel(
                                  context,
                                  _StageProofField(proof.$1, proof.$2, ''),
                                ),
                                path: proof.$3,
                              ),
                        ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

List<String> _trackingDestinations(Map<String, dynamic> freight) {
  final details = freight['stop_details'];
  if (details is List) {
    final names =
        details
            .whereType<Map>()
            .map((stop) => (stop['name'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toList();
    if (names.isNotEmpty) return names;
  }
  return [
    ...(freight['stops'] as List? ?? const []).map(
      (stop) => stop.toString().trim(),
    ),
    (freight['destination_town'] ?? '').toString().trim(),
  ].where((name) => name.isNotEmpty).toList();
}

String _trackingNumbers(dynamic values) {
  if (values is! List) return '—';
  final numbers =
      values
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
  return numbers.isEmpty ? '—' : numbers.join(', ');
}

class _StageTextField {
  const _StageTextField(this.label, this.key, {this.hint, this.keyboardType});

  final String label;
  final String key;
  final String? hint;
  final TextInputType? keyboardType;
}

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.actionLabel,
    this.initialValue = '',
    this.maxLines = 1,
  });

  final String title;
  final String label;
  final String hint;
  final String actionLabel;
  final String initialValue;
  final int maxLines;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.opsCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _StageProofField {
  const _StageProofField(this.label, this.key, this.kind);

  final String label;
  final String key;
  final String kind;
}

class _StageEditDialog extends StatefulWidget {
  const _StageEditDialog({
    required this.freightId,
    required this.stage,
    required this.title,
    required this.initialData,
    this.dispatchManagerMode = false,
  });

  final String freightId;
  final String stage;
  final String title;
  final Map<String, dynamic> initialData;
  final bool dispatchManagerMode;

  @override
  State<_StageEditDialog> createState() => _StageEditDialogState();
}

class _StageEditDialogState extends State<_StageEditDialog> {
  late final List<_StageTextField> _fields;
  late final List<_StageProofField> _proofs;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String?> _proofPaths;
  late final TextEditingController _contractorName;
  late final TextEditingController _contractorPhone;
  late final TextEditingController _contractorFrom;
  late final TextEditingController _contractorTo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fields = _fieldsForStage(
      widget.stage,
      dispatchManagerMode: widget.dispatchManagerMode,
    );
    _proofs = _proofsForStage(
      widget.stage,
      dispatchManagerMode: widget.dispatchManagerMode,
    );
    _controllers = {
      for (final field in _fields)
        field.key: TextEditingController(
          text: (widget.initialData[field.key] ?? '').toString(),
        ),
    };
    _proofPaths = {
      for (final proof in _proofs)
        proof.key: (widget.initialData[proof.key] ?? '').toString().trim(),
    };

    final contractors = widget.initialData['contractors'];
    final firstContractor =
        contractors is List &&
                contractors.isNotEmpty &&
                contractors.first is Map
            ? Map<String, dynamic>.from(contractors.first as Map)
            : const <String, dynamic>{};
    _contractorName = TextEditingController(
      text: (firstContractor['name'] ?? '').toString(),
    );
    _contractorPhone = TextEditingController(
      text: (firstContractor['phone'] ?? '').toString(),
    );
    _contractorFrom = TextEditingController(
      text: (firstContractor['from'] ?? '').toString(),
    );
    _contractorTo = TextEditingController(
      text: (firstContractor['to'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _contractorName.dispose();
    _contractorPhone.dispose();
    _contractorFrom.dispose();
    _contractorTo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.title} check'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidanceCard(
                title: operationalCopy(
                  context,
                  'Compare before saving',
                  'सहेजने से पहले तुलना करें',
                ),
                message: operationalCopy(
                  context,
                  'Check the driver, route and attached documents. Add a clear note when anything differs.',
                  'ड्राइवर, मार्ग और दस्तावेज़ जाँचें। अंतर हो तो स्पष्ट टिप्पणी दें।',
                ),
                tone: WorkspaceTone.info,
              ),
              const SizedBox(height: 16),
              for (final field in _fields) ...[
                TextField(
                  controller: _controllers[field.key],
                  keyboardType: field.keyboardType,
                  decoration: InputDecoration(
                    labelText: _localizedStageFieldLabel(context, field),
                    hintText: field.hint,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.stage == 'in_transit') ...[
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.opsSubContractorOptional,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contractorName,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.opsName,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contractorPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                OperationalFields(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _contractorFrom,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.opsFrom,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _contractorTo,
                        decoration: const InputDecoration(labelText: 'To'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              for (final proof in _proofs) ...[
                _DeliveryProofUploadField(
                  label: _localizedProofLabel(context, proof),
                  freightId: widget.freightId,
                  stage: widget.stage.replaceAll('_', '-'),
                  kind: proof.kind,
                  initialPath: _proofPaths[proof.key],
                  onUploaded:
                      (path) => setState(() => _proofPaths[proof.key] = path),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context)!.opsCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child:
              _saving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(AppLocalizations.of(context)!.opsSave),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
      for (final entry in _proofPaths.entries)
        entry.key: (entry.value ?? '').trim().isEmpty ? null : entry.value,
    };
    for (final field in _fields) {
      if (!field.key.contains('phone')) continue;
      final raw = (payload[field.key] ?? '').toString();
      if (raw.trim().isEmpty) continue;
      final normalized = normalizeIndianPhone(raw);
      if (normalized == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${field.label} must be a valid Indian mobile number',
            ),
          ),
        );
        setState(() => _saving = false);
        return;
      }
      payload[field.key] = normalized;
    }
    if (widget.stage == 'in_transit') {
      final contractor = {
        'name': _contractorName.text.trim(),
        'phone': _contractorPhone.text.trim(),
        'from': _contractorFrom.text.trim(),
        'to': _contractorTo.text.trim(),
      };
      if (contractor['phone']!.isNotEmpty) {
        final normalized = normalizeIndianPhone(contractor['phone']!);
        if (normalized == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sub-contractor phone must be a valid Indian mobile number',
              ),
            ),
          );
          setState(() => _saving = false);
          return;
        }
        contractor['phone'] = normalized;
      }
      payload['contractors'] =
          contractor.values.any((value) => value.isNotEmpty)
              ? [contractor]
              : const [];
    }

    try {
      await FreightsRepo.instance.saveDeliveryStageCheck(
        freightId: widget.freightId,
        stage: widget.stage,
        data: payload,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      setState(() => _saving = false);
    }
  }
}

String _localizedStageFieldLabel(BuildContext context, _StageTextField field) {
  final l = AppLocalizations.of(context)!;
  return switch (field.key) {
    'lorry_number' => l.opsLorryNumber,
    'driver_name' => l.opsDriverName,
    'driver_phone' => l.opsDriverPhone,
    'invoice_number' => l.opsInvoiceNumber,
    'gr_bilty_number' => l.opsGrBiltyNumber,
    'e_way_bill_number' => l.opsEwayBillNumber,
    'last_location' => l.opsCurrentLocation,
    'receiver_name' => l.opsReceiverName,
    'receiver_phone' => l.opsReceiverPhone,
    'gr_number' => l.opsGrNumber,
    'bill_reason' => l.opsAdditionalBillReason,
    _ => field.label,
  };
}

String _localizedProofLabel(BuildContext context, _StageProofField proof) {
  final l = AppLocalizations.of(context)!;
  return switch (proof.key) {
    'lorry_photo_path' => l.opsLorryPhoto,
    'driver_photo_path' => l.opsDriverPhoto,
    'driver_aadhaar_photo_path' => l.opsDriverAadhaar,
    'invoice_photo_path' => l.opsInvoicePhoto,
    'site_photo_path' => l.opsSitePhoto,
    'pod_photo_path' => l.opsProofOfDelivery,
    'bill_photo_path' => l.opsBillPhoto,
    _ => proof.label,
  };
}

List<_StageTextField> _fieldsForStage(
  String stage, {
  bool dispatchManagerMode = false,
}) {
  late final List<_StageTextField> fields;
  switch (stage) {
    case 'dispatched':
      fields = const [
        _StageTextField('Lorry number', 'lorry_number', hint: 'PB-08-AB-1234'),
        _StageTextField('Driver name', 'driver_name', hint: 'Rakesh Kumar'),
        _StageTextField(
          'Driver phone',
          'driver_phone',
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
        ),
      ];
    case 'pickup':
      fields = const [
        _StageTextField('Invoice number', 'invoice_number', hint: 'INV-1001'),
        _StageTextField(
          'Driver phone',
          'driver_phone',
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
        ),
      ];
    case 'in_transit':
      fields = const [
        _StageTextField(
          'GR / Bilty number',
          'gr_bilty_number',
          hint: 'GR-7821',
        ),
        _StageTextField(
          'E-way bill number',
          'e_way_bill_number',
          hint: 'EWB-1122334455',
        ),
        _StageTextField(
          'Current location',
          'last_location',
          hint: 'Ambala bypass',
        ),
      ];
    case 'delivered':
      fields = const [
        _StageTextField('Receiver name', 'receiver_name', hint: 'Vijay Rajput'),
        _StageTextField(
          'Receiver phone',
          'receiver_phone',
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
        ),
        _StageTextField('GR number', 'gr_number', hint: 'GR-4521'),
        _StageTextField(
          'E-way bill number',
          'e_way_bill_number',
          hint: 'EWB-1122334455',
        ),
        _StageTextField(
          'Additional bill reason',
          'bill_reason',
          hint: 'Loading charges',
        ),
      ];
    default:
      fields = const <_StageTextField>[];
  }
  if (!dispatchManagerMode) return fields;
  return fields.where((field) => !_isRestrictedDocumentKey(field.key)).toList();
}

List<_StageProofField> _proofsForStage(
  String stage, {
  bool dispatchManagerMode = false,
}) {
  late final List<_StageProofField> proofs;
  switch (stage) {
    case 'dispatched':
      proofs = const [
        _StageProofField('Lorry photo', 'lorry_photo_path', 'lorry'),
        _StageProofField('Driver photo', 'driver_photo_path', 'driver'),
        _StageProofField(
          'Driver Aadhaar',
          'driver_aadhaar_photo_path',
          'driver-aadhaar',
        ),
      ];
    case 'pickup':
      proofs = const [
        _StageProofField('Invoice photo', 'invoice_photo_path', 'invoice'),
        _StageProofField('Site photo', 'site_photo_path', 'site'),
      ];
    case 'in_transit':
      proofs = const [
        _StageProofField('Site photo', 'site_photo_path', 'site'),
      ];
    case 'delivered':
      proofs = const [
        _StageProofField('Proof of delivery', 'pod_photo_path', 'pod'),
        _StageProofField('Bill photo', 'bill_photo_path', 'bill'),
        _StageProofField('Site photo', 'site_photo_path', 'site'),
      ];
    default:
      proofs = const <_StageProofField>[];
  }
  if (!dispatchManagerMode) return proofs;
  return proofs.where((proof) => !_isRestrictedDocumentKey(proof.key)).toList();
}

bool _isRestrictedDocumentKey(String key) => const {
  'invoice_number',
  'invoice_photo_path',
  'gr_bilty_number',
  'gr_number',
  'e_way_bill_number',
  'bill_reason',
  'bill_photo_path',
}.contains(key);

class _DeliveryProofUploadField extends StatefulWidget {
  const _DeliveryProofUploadField({
    required this.label,
    required this.freightId,
    required this.stage,
    required this.kind,
    required this.onUploaded,
    this.initialPath,
  });

  final String label;
  final String freightId;
  final String stage;
  final String kind;
  final String? initialPath;
  final ValueChanged<String> onUploaded;

  @override
  State<_DeliveryProofUploadField> createState() =>
      _DeliveryProofUploadFieldState();
}

class _DeliveryProofUploadFieldState extends State<_DeliveryProofUploadField> {
  bool _uploading = false;
  String? _path;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
  }

  String _cleanSegment(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return cleaned.isEmpty ? 'upload' : cleaned;
  }

  String _contentType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.opsCouldNotReadImage),
          ),
        );
        return;
      }

      setState(() => _uploading = true);
      final extension = _cleanSegment(file.extension ?? 'jpg');
      final originalName = file.name;
      final baseName =
          originalName.toLowerCase().endsWith('.${extension.toLowerCase()}')
              ? originalName.substring(
                0,
                originalName.length - extension.length - 1,
              )
              : originalName;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}-${_cleanSegment(baseName)}';
      final path =
          '$uid/${widget.freightId}/${widget.stage}/${widget.kind}/$fileName.$extension';

      await supabase.storage
          .from('delivery-documents')
          .uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: _contentType(file.extension),
              upsert: true,
            ),
          );
      if (!mounted) return;
      setState(() => _path = path);
      widget.onUploaded(path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.opsPhotoUploaded)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = (_path ?? '').isNotEmpty;
    return Material(
      color: uploaded ? const Color(0xFFE7F6EC) : const Color(0xFFF7F2FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCAC4D0)),
      ),
      child: InkWell(
        onTap:
            _uploading
                ? null
                : uploaded
                ? () => showDeliveryDocumentPreview(
                  context: context,
                  title: widget.label,
                  path: _path!,
                  onReplace: _pickAndUpload,
                )
                : _pickAndUpload,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (_uploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  uploaded
                      ? Icons.check_circle_outline
                      : Icons.cloud_upload_outlined,
                  size: 18,
                  color:
                      uploaded
                          ? const Color(0xFF146C2E)
                          : const Color(0xFF625B71),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _uploading
                      ? 'Uploading...'
                      : uploaded
                      ? '${widget.label} uploaded'
                      : 'Upload ${widget.label.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
