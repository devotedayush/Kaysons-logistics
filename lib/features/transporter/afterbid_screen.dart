import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/widgets/india_city_field.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'widgets/transporter_workspace.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/storage_photo_viewer.dart';
import '../../l10n/app_localizations.dart';
import '../delivery/delivery_workflow_panel.dart';

class AfterbidScreen extends StatefulWidget {
  const AfterbidScreen({super.key, required this.bidId, this.freightStream});

  final String bidId;
  final Stream<Map<String, dynamic>?>? freightStream;

  @override
  State<AfterbidScreen> createState() => _AfterbidScreenState();
}

class _AfterbidScreenState extends State<AfterbidScreen> {
  String get bidId => widget.bidId;
  Stream<Map<String, dynamic>?>? get freightStream => widget.freightStream;
  final _dispatchKey = GlobalKey();
  final _pickupKey = GlobalKey();
  final _transitKey = GlobalKey();
  final _deliveryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: freightStream ?? FreightsRepo.instance.streamFreight(bidId),
          builder: (context, snap) {
            final freight = snap.data;
            if (snap.hasError) {
              return WorkspaceEmptyState(
                title: tpText(
                  context,
                  'Trip details could not be loaded',
                  'यात्रा का विवरण लोड नहीं हुआ',
                ),
                message: tpText(
                  context,
                  'Check your connection and return to your trips.',
                  'इंटरनेट जाँचकर अपनी यात्राओं पर लौटें।',
                ),
                icon: Icons.wifi_off,
                action: FilledButton(
                  onPressed: () => context.go('/fleet'),
                  child: Text(tpText(context, 'My trips', 'मेरी यात्राएँ')),
                ),
              );
            }
            if (freight == null) {
              if (snap.connectionState == ConnectionState.active ||
                  snap.connectionState == ConnectionState.done) {
                return WorkspaceEmptyState(
                  title: tpText(
                    context,
                    'This trip is unavailable',
                    'यह यात्रा उपलब्ध नहीं',
                  ),
                  message: tpText(
                    context,
                    'Return to your trips and choose an available journey.',
                    'अपनी यात्राओं पर लौटकर उपलब्ध यात्रा चुनें।',
                  ),
                  icon: Icons.route_outlined,
                  action: FilledButton(
                    onPressed: () => context.go('/fleet'),
                    child: Text(tpText(context, 'My trips', 'मेरी यात्राएँ')),
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            final stages = Map<String, dynamic>.from(
              freight['delivery_stages'] as Map? ?? {},
            );
            final destinations = _deliveryDestinations(freight);
            final hasMultipleDestinations = destinations.length > 1;
            final receivingWorkflow = freight['delivery_workflow_version'] == 1;
            final route =
                '${freight['origin']} → ${freight['destination_town']}';
            final progressLabel = _progressLabel(
              context,
              freight,
              stages,
              destinationCount: destinations.length,
            );
            final next =
                !stages.containsKey('dispatched')
                    ? 0
                    : !stages.containsKey('pickup')
                    ? 1
                    : receivingWorkflow || !stages.containsKey('in_transit')
                    ? 2
                    : 3;
            final l = AppLocalizations.of(context)!;
            final titles = [
              l.tpDispatched,
              l.tpPickup,
              receivingWorkflow
                  ? tpText(
                    context,
                    'Journey & customer reports',
                    'यात्रा और ग्राहक रिपोर्ट',
                  )
                  : l.tpInTransit,
              l.tpDelivered,
            ];
            final descriptions = [
              tpText(
                context,
                'Choose the vehicle and driver, then share their details with the office.',
                'वाहन और ड्राइवर चुनकर कार्यालय को जानकारी दें।',
              ),
              tpText(
                context,
                'Confirm pickup once the driver has reached the loading point.',
                'ड्राइवर के माल उठाने की जगह पहुँचने पर पुष्टि करें।',
              ),
              tpText(
                context,
                receivingWorkflow
                    ? 'Record location updates, customer handovers and extra expenses separately.'
                    : 'Share the journey update and any required transport references.',
                receivingWorkflow
                    ? 'स्थान, ग्राहक डिलीवरी और अतिरिक्त खर्च अलग-अलग दर्ज करें।'
                    : 'यात्रा अपडेट और ज़रूरी दस्तावेज़ संख्या दें।',
              ),
              tpText(
                context,
                'Record the receiver and upload delivery proof. Office acceptance is a separate check.',
                'प्राप्तकर्ता और डिलीवरी प्रमाण दर्ज करें। कार्यालय की स्वीकृति अलग जाँच है।',
              ),
            ];
            final finished =
                freight['ack_status'] == 'received' ||
                freight['status'] == 'completed' ||
                (!receivingWorkflow &&
                    (hasMultipleDestinations
                        ? (stages['delivered_stops'] as List? ?? [])
                                .where(
                                  (r) => r is Map && r['submitted_at'] != null,
                                )
                                .length >=
                            destinations.length
                        : stages.containsKey('delivered')));
            final keys = [_dispatchKey, _pickupKey, _transitKey, _deliveryKey];
            void jump() {
              final target = keys[next].currentContext;
              if (target != null) {
                Scrollable.ensureVisible(
                  target,
                  duration: const Duration(milliseconds: 350),
                  alignment: .05,
                );
              }
            }

            final stagesContent = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: _dispatchKey,
                  child: _DispatchedPanel(
                    bidId: bidId,
                    saved: stages['dispatched'],
                  ),
                ),
                _LmVehicleConfirmationBanner(stages: stages),
                KeyedSubtree(
                  key: _pickupKey,
                  child: _PickupPanel(bidId: bidId, saved: stages['pickup']),
                ),
                if (receivingWorkflow)
                  KeyedSubtree(
                    key: _transitKey,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DeliveryWorkflowPanel(
                        key: ValueKey('workflow-$bidId'),
                        freight: freight,
                      ),
                    ),
                  ),
                if (!receivingWorkflow)
                  KeyedSubtree(
                    key: _transitKey,
                    child: _InTransitPanel(
                      bidId: bidId,
                      saved: stages['in_transit'],
                      hasMultipleDestinations: hasMultipleDestinations,
                    ),
                  ),
                if (!receivingWorkflow)
                  KeyedSubtree(
                    key: _deliveryKey,
                    child: Column(
                      children: [
                        if (hasMultipleDestinations)
                          for (final (index, destination)
                              in destinations.indexed)
                            _DeliveredPanel(
                              key: ValueKey('delivery-stop-$index'),
                              bidId: bidId,
                              saved: _savedDeliveryStop(stages, index),
                              stopIndex: index,
                              destination: destination,
                            )
                        else
                          _DeliveredPanel(
                            bidId: bidId,
                            saved: stages['delivered'],
                          ),
                      ],
                    ),
                  ),
              ],
            );
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      tpText(context, 'Back to trips', 'यात्राओं पर वापस'),
                    ),
                  ),
                ),
                WorkspaceHeader(
                  title: route,
                  description: tpText(
                    context,
                    'Follow the steps below as the trip progresses. Saved information stays available for review.',
                    'यात्रा आगे बढ़ने पर नीचे दिए काम पूरे करें। सहेजी जानकारी बाद में भी देख सकते हैं।',
                  ),
                  icon: Icons.route_outlined,
                  eyebrow: l.tpDeliveryProgress,
                  summary: StatusBadge(
                    label: progressLabel,
                    tone:
                        freight['ack_status'] == 'received' ||
                                freight['status'] == 'completed'
                            ? WorkspaceTone.success
                            : WorkspaceTone.info,
                  ),
                ),
                const SizedBox(height: 20),
                GuidanceCard(
                  title: tpText(
                    context,
                    finished ? 'Delivery recorded' : 'Next: ${titles[next]}',
                    finished ? 'डिलीवरी दर्ज है' : 'अगला काम: ${titles[next]}',
                  ),
                  message:
                      finished
                          ? tpText(
                            context,
                            'Review the saved information below. Office POD acceptance and expense review remain separate.',
                            'नीचे सहेजी जानकारी देखें। कार्यालय की POD स्वीकृति और खर्च की जाँच अलग हैं।',
                          )
                          : descriptions[next],
                  icon: Icons.arrow_forward,
                  tone: WorkspaceTone.info,
                  action: FilledButton.icon(
                    onPressed: jump,
                    icon: const Icon(Icons.arrow_downward),
                    label: Text(
                      tpText(
                        context,
                        finished ? 'Review delivery record' : 'Go to this step',
                        finished ? 'डिलीवरी विवरण देखें' : 'इस काम पर जाएँ',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                WorkspaceFormLayout(
                  content: stagesContent,
                  aside: WorkspaceSection(
                    title: tpText(context, 'Trip at a glance', 'यात्रा का सार'),
                    children: [
                      Text(
                        '${tpText(context, 'Load', 'माल')}: ${freight['cases'] ?? '—'} ${tpText(context, 'cases', 'केस')} · ${freight['weight_kg'] ?? '—'} MT',
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      for (final (index, title) in titles.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                index < next
                                    ? Icons.check_circle_outline
                                    : index == next
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color:
                                    index < next
                                        ? const Color(0xFF146C4B)
                                        : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${index + 1}. $title',
                                  style: const TextStyle(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      GuidanceCard(
                        title: tpText(
                          context,
                          'Saved details',
                          'सहेजी जानकारी',
                        ),
                        message: tpText(
                          context,
                          'Open a finished step to review it. Uploading a POD and office approval are separate steps.',
                          'पूरा काम खोलकर जानकारी देखें। POD जोड़ना और कार्यालय की स्वीकृति अलग काम हैं।',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  String _progressLabel(
    BuildContext context,
    Map<String, dynamic> freight,
    Map<String, dynamic> stages, {
    required int destinationCount,
  }) {
    final l = AppLocalizations.of(context)!;
    if (freight['delivery_workflow_version'] == 1) {
      if (freight['ack_status'] == 'received') return l.tpCompleted;
      if (freight['status'] == 'dispatched' || freight['status'] == 'locked') {
        return l.tpInTransitCaps;
      }
    }
    if (destinationCount > 1) {
      final deliveredCount =
          (stages['delivered_stops'] as List? ?? const [])
              .where((item) => item is Map && item['submitted_at'] != null)
              .length;
      if (deliveredCount >= destinationCount) return l.tpDeliveredCaps;
    } else if (stages.containsKey('delivered')) {
      return l.tpDeliveredCaps;
    }
    if (stages.containsKey('in_transit')) return l.tpInTransitCaps;
    if (stages.containsKey('pickup')) return l.tpPickupCaps;
    if (stages.containsKey('dispatched')) return l.tpDispatchedCaps;
    return switch (freight['status'] as String? ?? '') {
      'bidding' => l.tpBiddingOpen,
      'awarded' => l.tpAwarded,
      'locked' => l.tpLocked,
      'completed' => l.tpCompleted,
      'dispatched' => l.tpDispatchedCaps,
      final status => status.toUpperCase(),
    };
  }
}

List<String> _deliveryDestinations(Map<String, dynamic> freight) {
  final details = freight['stop_details'];
  if (details is List) {
    final names =
        details
            .whereType<Map>()
            .map((row) => (row['name'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toList();
    if (names.isNotEmpty) return names;
  }
  return [
    ...(freight['stops'] as List? ?? const [])
        .map((stop) => stop.toString().trim())
        .where((name) => name.isNotEmpty),
    (freight['destination_town'] ?? '').toString().trim(),
  ].where((name) => name.isNotEmpty).toList();
}

Map<String, dynamic>? _savedDeliveryStop(
  Map<String, dynamic> stages,
  int index,
) {
  final saved = stages['delivered_stops'];
  if (saved is! List) return null;
  for (final item in saved) {
    if (item is Map && item['stop_index'] == index) {
      return Map<String, dynamic>.from(item);
    }
  }
  return null;
}

class _LmVehicleConfirmationBanner extends StatelessWidget {
  const _LmVehicleConfirmationBanner({required this.stages});

  final Map<String, dynamic> stages;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!stages.containsKey('dispatched')) return const SizedBox.shrink();
    final confirmation = Map<String, dynamic>.from(
      stages['vehicle_confirmation'] as Map? ?? const {},
    );
    final status = (confirmation['status'] ?? '').toString();
    final note = (confirmation['note'] ?? '').toString();
    final confirmed = status == 'confirmed';
    final issue = status == 'issue';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            confirmed
                ? const Color(0xFFE7F6EC)
                : issue
                ? const Color(0xFFFFF1F0)
                : const Color(0xFFFFF8E1),
        border: Border.all(
          color:
              confirmed
                  ? const Color(0xFF77C28A)
                  : issue
                  ? const Color(0xFFE69A95)
                  : const Color(0xFFE7C65F),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            confirmed
                ? Icons.verified_outlined
                : issue
                ? Icons.report_problem_outlined
                : Icons.hourglass_top_outlined,
            color:
                confirmed
                    ? const Color(0xFF146C2E)
                    : issue
                    ? const Color(0xFFB3261E)
                    : const Color(0xFF7A5B00),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  confirmed
                      ? l.tpLmConfirmedVehicle
                      : issue
                      ? l.tpLmRaisedIssue
                      : l.tpWaitingVehicleConfirmation,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D1B20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note.isNotEmpty
                      ? note
                      : confirmed
                      ? l.tpVehicleConfirmedHint
                      : issue
                      ? l.tpDispatchUpdateHint
                      : l.tpDispatchChangeHint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF49454F),
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

// ---------- Shared panel scaffold ----------

class _StagePanel extends StatefulWidget {
  const _StagePanel({
    required this.title,
    required this.submitted,
    required this.child,
  });
  final String title;
  final bool submitted;
  final Widget child;

  @override
  State<_StagePanel> createState() => _StagePanelState();
}

class _StagePanelState extends State<_StagePanel> {
  late bool _open;
  @override
  void initState() {
    super.initState();
    _open = !widget.submitted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCAC4D0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (widget.submitted)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle,
                        color: Color(0xFF14A33A),
                        size: 20,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label:
                        widget.submitted
                            ? tpText(context, 'Saved', 'सहेजा')
                            : tpText(context, 'To do', 'बाकी'),
                    tone:
                        widget.submitted
                            ? WorkspaceTone.success
                            : WorkspaceTone.neutral,
                  ),
                  const SizedBox(width: 8),
                  Icon(_open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _LabelField extends StatelessWidget {
  const _LabelField({required this.label, required this.child});
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

class _UploadField extends StatefulWidget {
  const _UploadField({
    super.key,
    required this.label,
    required this.bidId,
    required this.stage,
    required this.kind,
    required this.onUploaded,
    this.initialPath,
  });

  final String label;
  final String bidId;
  final String stage;
  final String kind;
  final String? initialPath;
  final ValueChanged<String> onUploaded;

  @override
  State<_UploadField> createState() => _UploadFieldState();
}

class _UploadFieldState extends State<_UploadField> {
  bool _uploading = false;
  String? _path;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
  }

  @override
  void didUpdateWidget(covariant _UploadField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPath != widget.initialPath) {
      _path = widget.initialPath;
    }
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
            content: Text(AppLocalizations.of(context)!.tpCouldNotReadImage),
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
          '$uid/${widget.bidId}/${widget.stage}/${widget.kind}/$fileName.$extension';
      final data = Uint8List.fromList(bytes);

      await supabase.storage
          .from('delivery-documents')
          .uploadBinary(
            path,
            data,
            fileOptions: FileOptions(
              contentType: _contentType(file.extension),
              upsert: true,
            ),
          );
      if (!mounted) return;
      setState(() => _path = path);
      widget.onUploaded(path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.tpPhotoUploaded)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tpUploadFailed('$e')),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = (_path ?? '').isNotEmpty;
    return Material(
      color: uploaded ? const Color(0xFFE7F6EC) : const Color(0xFFE8E7E7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
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
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_uploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  uploaded
                      ? Icons.check_circle_outline
                      : Icons.cloud_upload_outlined,
                  size: 16,
                  color:
                      uploaded
                          ? const Color(0xFF14A33A)
                          : const Color(0xFF625B71),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _uploading
                      ? AppLocalizations.of(context)!.tpUploading
                      : uploaded
                      ? AppLocalizations.of(context)!.tpUploadedPreview
                      : widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        uploaded
                            ? const Color(0xFF146C2E)
                            : const Color(0xFF625B71),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _save(
  BuildContext context,
  String bidId,
  String stage,
  Map<String, dynamic> data,
) async {
  try {
    _normalizeStagePhones(data);
    await FreightsRepo.instance.saveDeliveryStage(
      freightId: bidId,
      stage: stage,
      data: data,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.tpSaved)),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is FormatException
              ? AppLocalizations.of(context)!.tpEnterValidPhone
              : AppLocalizations.of(context)!.tpSaveFailed('$e'),
        ),
      ),
    );
  }
}

// Validate supplied contact fields, including subcontractor rows, before saving.
void _normalizeStagePhones(dynamic value) {
  if (value is Map) {
    for (final key in value.keys.toList()) {
      final field = key.toString();
      if (field == 'phone' || field.endsWith('_phone')) {
        final raw = (value[key] ?? '').toString().trim();
        if (raw.isEmpty) continue;
        final normalized = normalizeIndianPhone(raw);
        if (normalized == null) {
          throw const FormatException('Enter a valid Indian mobile number');
        }
        value[key] = normalized;
      } else {
        _normalizeStagePhones(value[key]);
      }
    }
  } else if (value is List) {
    for (final item in value) {
      _normalizeStagePhones(item);
    }
  }
}

// ---------- Dispatched ----------

class _DispatchedPanel extends StatefulWidget {
  const _DispatchedPanel({required this.bidId, required this.saved});
  final String bidId;
  final dynamic saved;

  @override
  State<_DispatchedPanel> createState() => _DispatchedPanelState();
}

class _DispatchedPanelState extends State<_DispatchedPanel> {
  late final TextEditingController _lorry;
  late final TextEditingController _driver;
  late final TextEditingController _phone;
  String? _vehicleId;
  String? _driverId;
  String? _lorryPhotoPath;
  String? _driverPhotoPath;
  String? _driverAadhaarPath;
  bool _saving = false;
  int _selectionVersion = 0;

  @override
  void initState() {
    super.initState();
    final s = widget.saved as Map<String, dynamic>? ?? {};
    _lorry = TextEditingController(text: s['lorry_number'] ?? '');
    _driver = TextEditingController(text: s['driver_name'] ?? '');
    _phone = TextEditingController(text: s['driver_phone'] ?? '');
    _vehicleId = s['vehicle_id'] as String?;
    _driverId = s['driver_id'] as String?;
    _lorryPhotoPath = s['lorry_photo_path'] as String?;
    _driverPhotoPath = s['driver_photo_path'] as String?;
    _driverAadhaarPath = s['driver_aadhaar_photo_path'] as String?;
  }

  @override
  void dispose() {
    _lorry.dispose();
    _driver.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StagePanel(
      title: AppLocalizations.of(context)!.tpDispatched,
      submitted: widget.saved != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SavedVehiclePicker(
            key: ValueKey('vehicles-$_selectionVersion'),
            selectedId: _vehicleId,
            onPick: (vehicle) {
              setState(() {
                _vehicleId = vehicle['id'] as String?;
                _lorry.text = (vehicle['registration_number'] ?? '').toString();
              });
            },
            onAdd: () async {
              await context.push('/vehicles');
              if (mounted) setState(() => _selectionVersion++);
            },
          ),
          _SavedDriverPicker(
            key: ValueKey('drivers-$_selectionVersion'),
            selectedId: _driverId,
            onPick: (driver) {
              setState(() {
                _driverId = driver['id'] as String?;
                _driver.text = (driver['name'] ?? '').toString();
                _phone.text = (driver['phone'] ?? '').toString();
              });
            },
            onAdd: () async {
              await context.push('/drivers');
              if (mounted) setState(() => _selectionVersion++);
            },
          ),
          _SectionHeader(AppLocalizations.of(context)!.tpLorryProof),
          _LabelField(
            label: AppLocalizations.of(context)!.tpAddLorryPhotograph,
            child: _UploadField(
              label: AppLocalizations.of(context)!.tpUploadLorryPhoto,
              bidId: widget.bidId,
              stage: 'dispatched',
              kind: 'lorry',
              initialPath: _lorryPhotoPath,
              onUploaded: (path) => _lorryPhotoPath = path,
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(AppLocalizations.of(context)!.tpDriverProof),
          _LabelField(
            label: AppLocalizations.of(context)!.tpEnterDriverPhotograph,
            child: _UploadField(
              label: AppLocalizations.of(context)!.tpUploadDriverPhoto,
              bidId: widget.bidId,
              stage: 'dispatched',
              kind: 'driver',
              initialPath: _driverPhotoPath,
              onUploaded: (path) => _driverPhotoPath = path,
            ),
          ),
          _LabelField(
            label: AppLocalizations.of(context)!.tpDriverAadhaarPhoto,
            child: _UploadField(
              label: AppLocalizations.of(context)!.tpUploadDriverAadhaar,
              bidId: widget.bidId,
              stage: 'dispatched',
              kind: 'driver-aadhaar',
              initialPath: _driverAadhaarPath,
              onUploaded: (path) => _driverAadhaarPath = path,
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label:
                _saving
                    ? AppLocalizations.of(context)!.tpSavingEllipsis
                    : AppLocalizations.of(context)!.tpSubmitLorryDetails,
            onPressed:
                _saving
                    ? null
                    : () async {
                      setState(() => _saving = true);
                      await _save(context, widget.bidId, 'dispatched', {
                        'lorry_number': _lorry.text.trim(),
                        'vehicle_id': _vehicleId,
                        'driver_name': _driver.text.trim(),
                        'driver_phone': _phone.text.trim(),
                        'driver_id': _driverId,
                        'lorry_photo_path': _lorryPhotoPath,
                        'driver_photo_path': _driverPhotoPath,
                        'driver_aadhaar_photo_path': _driverAadhaarPath,
                      });
                      if (mounted) setState(() => _saving = false);
                    },
          ),
        ],
      ),
    );
  }
}

class _SavedVehiclePicker extends StatelessWidget {
  const _SavedVehiclePicker({
    super.key,
    required this.selectedId,
    required this.onPick,
    required this.onAdd,
  });

  final String? selectedId;
  final ValueChanged<Map<String, dynamic>> onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('vehicles')
          .select(
            'id, registration_number, vehicle_type, capacity_qt, capacity_weight_kg, rc_number, insurance_number',
          )
          .eq('profile_id', uid)
          .order('updated_at', ascending: false)
          .then((rows) => (rows as List).cast<Map<String, dynamic>>()),
      builder: (context, snap) {
        final vehicles = snap.data ?? const <Map<String, dynamic>>[];
        final selected = _selectedRow(vehicles, selectedId);
        return _SavedEntitySelector(
          title: AppLocalizations.of(context)!.tpSelectVehicle,
          emptyText: AppLocalizations.of(context)!.tpNoSavedVehicles,
          selectedTitle:
              selected == null
                  ? AppLocalizations.of(context)!.tpChooseSavedFleet
                  : (selected['registration_number'] ??
                          AppLocalizations.of(context)!.tpVehicles)
                      .toString(),
          selectedSubtitle:
              selected == null
                  ? AppLocalizations.of(context)!.tpUseSavedVehicle
                  : _vehicleSummary(context, selected),
          icon: Icons.local_shipping_outlined,
          addLabel: AppLocalizations.of(context)!.tpAddVehicle,
          selectLabel:
              vehicles.isEmpty
                  ? null
                  : AppLocalizations.of(context)!.tpSelectVehicle,
          onAdd: onAdd,
          onSelect:
              vehicles.isEmpty
                  ? null
                  : () => _showVehiclePicker(context, vehicles, onPick),
        );
      },
    );
  }

  static Map<String, dynamic>? _selectedRow(
    List<Map<String, dynamic>> rows,
    String? id,
  ) {
    if (id == null) return null;
    for (final row in rows) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  static String _vehicleSummary(
    BuildContext context,
    Map<String, dynamic> vehicle,
  ) {
    final l = AppLocalizations.of(context)!;
    final capacity = [
      if ((vehicle['capacity_qt'] ?? '').toString().trim().isNotEmpty)
        l.tpCases('${vehicle['capacity_qt']}'),
      if ((vehicle['capacity_weight_kg'] ?? '').toString().trim().isNotEmpty)
        '${vehicle['capacity_weight_kg']} MT',
    ].join(' · ');
    return [
      (vehicle['vehicle_type'] ?? '').toString(),
      capacity,
      if ((vehicle['rc_number'] ?? '').toString().trim().isNotEmpty)
        l.tpRcSaved,
      if ((vehicle['insurance_number'] ?? '').toString().trim().isNotEmpty)
        l.tpInsuranceSaved,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
  }

  static Future<void> _showVehiclePicker(
    BuildContext context,
    List<Map<String, dynamic>> vehicles,
    ValueChanged<Map<String, dynamic>> onPick,
  ) async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => _EntityPickerSheet(
            title: AppLocalizations.of(context)!.tpSelectVehicle,
            rows: vehicles,
            icon: Icons.local_shipping_outlined,
            titleFor:
                (row) =>
                    (row['registration_number'] ??
                            AppLocalizations.of(context)!.tpVehicles)
                        .toString(),
            subtitleFor: (row) => _vehicleSummary(context, row),
          ),
    );
    if (picked != null) onPick(picked);
  }
}

class _SavedDriverPicker extends StatelessWidget {
  const _SavedDriverPicker({
    super.key,
    required this.selectedId,
    required this.onPick,
    required this.onAdd,
  });

  final String? selectedId;
  final ValueChanged<Map<String, dynamic>> onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('drivers')
          .select('id, name, phone, licence_number')
          .eq('transporter_id', uid)
          .order('updated_at', ascending: false)
          .then((rows) => (rows as List).cast<Map<String, dynamic>>()),
      builder: (context, snap) {
        final drivers = snap.data ?? const <Map<String, dynamic>>[];
        final selected = _selectedRow(drivers, selectedId);
        return _SavedEntitySelector(
          title: AppLocalizations.of(context)!.tpSelectDriver,
          emptyText: AppLocalizations.of(context)!.tpNoSavedDrivers,
          selectedTitle:
              selected == null
                  ? AppLocalizations.of(context)!.tpChooseSavedDrivers
                  : (selected['name'] ??
                          AppLocalizations.of(context)!.tpDrivers)
                      .toString(),
          selectedSubtitle:
              selected == null
                  ? AppLocalizations.of(context)!.tpUseSavedDriver
                  : [
                    (selected['phone'] ?? '').toString(),
                    if ((selected['licence_number'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      AppLocalizations.of(context)!.tpLicenceSaved,
                  ].where((value) => value.trim().isNotEmpty).join(' · '),
          icon: Icons.badge_outlined,
          addLabel: AppLocalizations.of(context)!.tpAddDriver,
          selectLabel:
              drivers.isEmpty
                  ? null
                  : AppLocalizations.of(context)!.tpSelectDriver,
          onAdd: onAdd,
          onSelect:
              drivers.isEmpty
                  ? null
                  : () => _showDriverPicker(context, drivers, onPick),
        );
      },
    );
  }

  static Map<String, dynamic>? _selectedRow(
    List<Map<String, dynamic>> rows,
    String? id,
  ) {
    if (id == null) return null;
    for (final row in rows) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  static Future<void> _showDriverPicker(
    BuildContext context,
    List<Map<String, dynamic>> drivers,
    ValueChanged<Map<String, dynamic>> onPick,
  ) async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => _EntityPickerSheet(
            title: AppLocalizations.of(context)!.tpSelectDriver,
            rows: drivers,
            icon: Icons.badge_outlined,
            titleFor:
                (row) =>
                    (row['name'] ?? AppLocalizations.of(context)!.tpDrivers)
                        .toString(),
            subtitleFor:
                (row) => [
                  (row['phone'] ?? '').toString(),
                  if ((row['licence_number'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    AppLocalizations.of(context)!.tpLicenceSaved,
                ].where((value) => value.trim().isNotEmpty).join(' · '),
          ),
    );
    if (picked != null) onPick(picked);
  }
}

class _SavedEntitySelector extends StatelessWidget {
  const _SavedEntitySelector({
    required this.title,
    required this.emptyText,
    required this.selectedTitle,
    required this.selectedSubtitle,
    required this.icon,
    required this.addLabel,
    required this.selectLabel,
    required this.onAdd,
    required this.onSelect,
  });

  final String title;
  final String emptyText;
  final String selectedTitle;
  final String selectedSubtitle;
  final IconData icon;
  final String addLabel;
  final String? selectLabel;
  final VoidCallback onAdd;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FB),
        border: Border.all(color: const Color(0xFFE4DCEB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D1B20),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8DEF8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF6750A4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      onSelect == null ? emptyText : selectedTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1B20),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF49454F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (selectLabel != null)
                FilledButton.tonalIcon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.checklist_outlined),
                  label: Text(selectLabel!),
                ),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(addLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntityPickerSheet extends StatelessWidget {
  const _EntityPickerSheet({
    required this.title,
    required this.rows,
    required this.icon,
    required this.titleFor,
    required this.subtitleFor,
  });

  final String title;
  final List<Map<String, dynamic>> rows;
  final IconData icon;
  final String Function(Map<String, dynamic>) titleFor;
  final String Function(Map<String, dynamic>) subtitleFor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                final subtitle = subtitleFor(row);
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE4DCEB)),
                  ),
                  leading: Icon(icon, color: const Color(0xFF6750A4)),
                  title: Text(titleFor(row)),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, row),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Pickup ----------

class _PickupPanel extends StatefulWidget {
  const _PickupPanel({required this.bidId, required this.saved});
  final String bidId;
  final dynamic saved;

  @override
  State<_PickupPanel> createState() => _PickupPanelState();
}

class _PickupPanelState extends State<_PickupPanel> {
  late final TextEditingController _phone;
  String? _sitePhotoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.saved as Map<String, dynamic>? ?? {};
    _phone = TextEditingController(text: s['driver_phone'] ?? '');
    _sitePhotoPath = s['site_photo_path'] as String?;
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StagePanel(
      title: AppLocalizations.of(context)!.tpPickup,
      submitted: widget.saved != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(AppLocalizations.of(context)!.tpPickupDetails),
          _LabelField(
            label: AppLocalizations.of(context)!.tpEnterDriverPhone,
            child: PillTextField(
              controller: _phone,
              hint: '987 - 6541 - 321',
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: AppLocalizations.of(context)!.tpEnterSitePhoto,
            child: _UploadField(
              label: AppLocalizations.of(context)!.tpUploadPresence,
              bidId: widget.bidId,
              stage: 'pickup',
              kind: 'site',
              initialPath: _sitePhotoPath,
              onUploaded: (path) => _sitePhotoPath = path,
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label:
                _saving
                    ? AppLocalizations.of(context)!.tpSavingEllipsis
                    : AppLocalizations.of(context)!.tpSubmitPickup,
            onPressed:
                _saving
                    ? null
                    : () async {
                      setState(() => _saving = true);
                      await _save(context, widget.bidId, 'pickup', {
                        'driver_phone': _phone.text.trim(),
                        'site_photo_path': _sitePhotoPath,
                      });
                      if (mounted) setState(() => _saving = false);
                    },
          ),
        ],
      ),
    );
  }
}

// ---------- In Transit ----------

class _Contractor {
  _Contractor({this.name = '', this.phone = '', this.from = '', this.to = ''});
  String name;
  String phone;
  String from;
  String to;

  Map<String, String> toJson() => {
    'name': name,
    'phone': phone,
    'from': from,
    'to': to,
  };

  static _Contractor fromJson(Map m) => _Contractor(
    name: (m['name'] ?? '').toString(),
    phone: (m['phone'] ?? '').toString(),
    from: (m['from'] ?? '').toString(),
    to: (m['to'] ?? '').toString(),
  );
}

class _InTransitPanel extends StatefulWidget {
  const _InTransitPanel({
    required this.bidId,
    required this.saved,
    required this.hasMultipleDestinations,
  });
  final String bidId;
  final dynamic saved;
  final bool hasMultipleDestinations;

  @override
  State<_InTransitPanel> createState() => _InTransitPanelState();
}

class _InTransitPanelState extends State<_InTransitPanel> {
  final List<_Contractor> _contractors = [];
  late final TextEditingController _grBilty;
  late final TextEditingController _eWayBill;
  late final TextEditingController _lastLocation;
  String? _sitePhotoPath;
  bool _saving = false;
  bool _savingLocation = false;

  @override
  void initState() {
    super.initState();
    final s = widget.saved as Map<String, dynamic>? ?? {};
    final list = (s['contractors'] as List?) ?? const [];
    if (list.isNotEmpty) {
      _contractors.addAll(list.map((m) => _Contractor.fromJson(m as Map)));
    } else {
      _contractors.add(_Contractor());
    }
    _grBilty = TextEditingController(text: s['gr_bilty_number'] ?? '');
    _eWayBill = TextEditingController(text: s['e_way_bill_number'] ?? '');
    _lastLocation = TextEditingController(text: s['last_location'] ?? '');
    _sitePhotoPath = s['site_photo_path'] as String?;
  }

  @override
  void dispose() {
    _grBilty.dispose();
    _eWayBill.dispose();
    _lastLocation.dispose();
    super.dispose();
  }

  void _addContractor() {
    setState(() => _contractors.add(_Contractor()));
  }

  void _removeContractor(int i) {
    setState(() {
      _contractors.removeAt(i);
      if (_contractors.isEmpty) _contractors.add(_Contractor());
    });
  }

  @override
  Widget build(BuildContext context) {
    return _StagePanel(
      title: AppLocalizations.of(context)!.tpInTransit,
      submitted: widget.saved != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.tpSubcontractors),
              subtitle: Text(
                tpText(
                  context,
                  'Add only if someone else helps on the route.',
                  'रास्ते में किसी और की मदद होने पर ही जोड़ें।',
                ),
              ),
              children: [
                _SectionHeader(AppLocalizations.of(context)!.tpSubcontractors),
                ..._contractors.asMap().entries.map(
                  (e) => _contractorCard(e.key, e.value),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _addContractor,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(AppLocalizations.of(context)!.tpAddContractor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!widget.hasMultipleDestinations) ...[
            _SectionHeader(AppLocalizations.of(context)!.tpVerificationDetails),
            _LabelField(
              label: AppLocalizations.of(context)!.tpGrBiltyNumber,
              child: PillTextField(
                controller: _grBilty,
                hint: 'GR-7821',
                textAlign: TextAlign.start,
              ),
            ),
            _LabelField(
              label: AppLocalizations.of(context)!.tpEwayBillNumber,
              child: PillTextField(
                controller: _eWayBill,
                hint: 'EWB-1122334455',
                textAlign: TextAlign.start,
              ),
            ),
          ],
          _LabelField(
            label: AppLocalizations.of(context)!.tpCurrentLocation,
            child: PillTextField(
              controller: _lastLocation,
              hint: AppLocalizations.of(context)!.tpLocationHint,
              textAlign: TextAlign.start,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed:
                  _savingLocation
                      ? null
                      : () async {
                        final location = _lastLocation.text.trim();
                        if (location.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                )!.tpEnterCurrentLocation,
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _savingLocation = true);
                        try {
                          await FreightsRepo.instance.saveTransitLocation(
                            freightId: widget.bidId,
                            location: location,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.tpLocationUpdated,
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                )!.tpLocationUpdateFailed('$e'),
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _savingLocation = false);
                          }
                        }
                      },
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(
                _savingLocation
                    ? AppLocalizations.of(context)!.tpUpdating
                    : AppLocalizations.of(context)!.tpUpdateLocation,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_sitePhotoPath != null)
            _LabelField(
              label: AppLocalizations.of(context)!.tpTransitSitePhoto,
              child: _UploadField(
                label: AppLocalizations.of(context)!.tpUploadPresence,
                bidId: widget.bidId,
                stage: 'in-transit',
                kind: 'site',
                initialPath: _sitePhotoPath,
                onUploaded: (path) => _sitePhotoPath = path,
              ),
            ),
          const SizedBox(height: 8),
          PrimaryButton(
            label:
                _saving
                    ? AppLocalizations.of(context)!.tpSavingEllipsis
                    : AppLocalizations.of(context)!.tpShareTransit,
            onPressed:
                _saving
                    ? null
                    : () async {
                      setState(() => _saving = true);
                      final cleaned =
                          _contractors
                              .where(
                                (c) =>
                                    c.name.isNotEmpty ||
                                    c.phone.isNotEmpty ||
                                    c.from.isNotEmpty ||
                                    c.to.isNotEmpty,
                              )
                              .map((c) => c.toJson())
                              .toList();
                      await _save(context, widget.bidId, 'in_transit', {
                        'contractors': cleaned,
                        if (!widget.hasMultipleDestinations) ...{
                          'gr_bilty_number': _grBilty.text.trim(),
                          'e_way_bill_number': _eWayBill.text.trim(),
                        },
                        'last_location': _lastLocation.text.trim(),
                        'site_photo_path': _sitePhotoPath,
                      });
                      if (mounted) setState(() => _saving = false);
                    },
          ),
        ],
      ),
    );
  }

  Widget _contractorCard(int i, _Contractor c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EDFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.tpContractorNumber(i + 1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_contractors.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFB3261E),
                    size: 20,
                  ),
                  onPressed: () => _removeContractor(i),
                ),
            ],
          ),
          _fieldRow(
            AppLocalizations.of(context)!.tpName,
            c.name,
            (v) => c.name = v,
            'Vijaypratap Rajput',
          ),
          _fieldRow(
            AppLocalizations.of(context)!.tpPhone,
            c.phone,
            (v) => c.phone = v,
            '987-6543-654',
            keyboardType: TextInputType.phone,
          ),
          Row(
            children: [
              Expanded(
                child: _fieldRow(
                  AppLocalizations.of(context)!.tpFrom,
                  c.from,
                  (v) => c.from = v,
                  AppLocalizations.of(context)!.tpSelectCity,
                  useCityPicker: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _fieldRow(
                  AppLocalizations.of(context)!.tpTo,
                  c.to,
                  (v) => c.to = v,
                  AppLocalizations.of(context)!.tpSelectCity,
                  useCityPicker: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(
    String label,
    String initial,
    ValueChanged<String> onChanged,
    String hint, {
    TextInputType? keyboardType,
    bool useCityPicker = false,
  }) {
    if (useCityPicker) {
      return _CityFieldRow(
        label: label,
        initial: initial,
        hint: hint,
        onChanged: onChanged,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF49454F)),
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: initial,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF625B71),
                fontSize: 13,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFCAC4D0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFCAC4D0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFF1D1B20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityFieldRow extends StatefulWidget {
  const _CityFieldRow({
    required this.label,
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_CityFieldRow> createState() => _CityFieldRowState();
}

class _CityFieldRowState extends State<_CityFieldRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _controller.addListener(_syncValue);
  }

  @override
  void didUpdateWidget(covariant _CityFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial &&
        widget.initial != _controller.text) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncValue);
    _controller.dispose();
    super.dispose();
  }

  void _syncValue() => widget.onChanged(_controller.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF49454F)),
          ),
          const SizedBox(height: 4),
          IndiaCityField(
            controller: _controller,
            hint: widget.hint,
            fillColor: Colors.white,
            borderRadius: 20,
          ),
        ],
      ),
    );
  }
}

// ---------- Delivered ----------

class _DeliveredPanel extends StatefulWidget {
  const _DeliveredPanel({
    super.key,
    required this.bidId,
    required this.saved,
    this.stopIndex,
    this.destination,
  });
  final String bidId;
  final dynamic saved;
  final int? stopIndex;
  final String? destination;

  @override
  State<_DeliveredPanel> createState() => _DeliveredPanelState();
}

class _DeliveredPanelState extends State<_DeliveredPanel> {
  late final TextEditingController _receiver;
  late final TextEditingController _receiverPhone;
  late final TextEditingController _gr;
  late final TextEditingController _eWayBill;
  late final TextEditingController _billReason;
  List<String> _grNumbers = const [];
  List<String> _eWayBillNumbers = const [];
  String? _podPhotoPath;
  String? _billPhotoPath;
  String? _sitePhotoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.saved as Map<String, dynamic>? ?? {};
    _receiver = TextEditingController(text: s['receiver_name'] ?? '');
    _receiverPhone = TextEditingController(text: s['receiver_phone'] ?? '');
    _gr = TextEditingController(text: s['gr_number'] ?? '');
    _eWayBill = TextEditingController(text: s['e_way_bill_number'] ?? '');
    _billReason = TextEditingController(text: s['bill_reason'] ?? '');
    _grNumbers = _savedNumbers(s['gr_numbers']);
    _eWayBillNumbers = _savedNumbers(s['e_way_bill_numbers']);
    _podPhotoPath = s['pod_photo_path'] as String?;
    _billPhotoPath = s['bill_photo_path'] as String?;
    _sitePhotoPath = s['site_photo_path'] as String?;
  }

  @override
  void didUpdateWidget(covariant _DeliveredPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saved != widget.saved && _matchesSaved(oldWidget.saved)) {
      final saved = widget.saved as Map<String, dynamic>? ?? {};
      _receiver.text = (saved['receiver_name'] ?? '').toString();
      _receiverPhone.text = (saved['receiver_phone'] ?? '').toString();
      _gr.text = (saved['gr_number'] ?? '').toString();
      _eWayBill.text = (saved['e_way_bill_number'] ?? '').toString();
      _billReason.text = (saved['bill_reason'] ?? '').toString();
      _grNumbers = _savedNumbers(saved['gr_numbers']);
      _eWayBillNumbers = _savedNumbers(saved['e_way_bill_numbers']);
      _podPhotoPath = saved['pod_photo_path'] as String?;
      _billPhotoPath = saved['bill_photo_path'] as String?;
      _sitePhotoPath = saved['site_photo_path'] as String?;
    }
  }

  bool _matchesSaved(dynamic value) {
    final saved = value as Map<String, dynamic>? ?? {};
    return _receiver.text == (saved['receiver_name'] ?? '').toString() &&
        _receiverPhone.text == (saved['receiver_phone'] ?? '').toString() &&
        _gr.text == (saved['gr_number'] ?? '').toString() &&
        _eWayBill.text == (saved['e_way_bill_number'] ?? '').toString() &&
        _billReason.text == (saved['bill_reason'] ?? '').toString() &&
        _sameNumbers(_grNumbers, _savedNumbers(saved['gr_numbers'])) &&
        _sameNumbers(
          _eWayBillNumbers,
          _savedNumbers(saved['e_way_bill_numbers']),
        ) &&
        _podPhotoPath == saved['pod_photo_path'] &&
        _billPhotoPath == saved['bill_photo_path'] &&
        _sitePhotoPath == saved['site_photo_path'];
  }

  @override
  void dispose() {
    _receiver.dispose();
    _receiverPhone.dispose();
    _gr.dispose();
    _eWayBill.dispose();
    _billReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StagePanel(
      title:
          widget.destination == null
              ? AppLocalizations.of(context)!.tpDelivered
              : '${AppLocalizations.of(context)!.tpDelivered} · ${widget.destination}',
      submitted: widget.saved != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(AppLocalizations.of(context)!.tpDeliverySiteDetails),
          _LabelField(
            label: AppLocalizations.of(context)!.tpEnterReceiverName,
            child: PillTextField(
              controller: _receiver,
              hint: 'Vijaypratap Rajput',
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: AppLocalizations.of(context)!.tpEnterReceiverNumber,
            child: PillTextField(
              controller: _receiverPhone,
              hint: '987-6543-654',
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.start,
            ),
          ),
          if (widget.stopIndex == null) ...[
            _LabelField(
              label: AppLocalizations.of(context)!.tpEnterGrNumber,
              child: PillTextField(
                controller: _gr,
                hint: 'GR-4521',
                textAlign: TextAlign.start,
              ),
            ),
            _LabelField(
              label: AppLocalizations.of(context)!.tpEnterEwayBill,
              child: PillTextField(
                controller: _eWayBill,
                hint: 'EWB-1122334455',
                textAlign: TextAlign.start,
              ),
            ),
          ] else ...[
            _ReferenceListField(
              label: AppLocalizations.of(context)!.tpGrBiltyNumber,
              initialValues: _grNumbers,
              onChanged: (values) => _grNumbers = values,
            ),
            _ReferenceListField(
              label: AppLocalizations.of(context)!.tpEwayBillNumber,
              initialValues: _eWayBillNumbers,
              onChanged: (values) => _eWayBillNumbers = values,
            ),
          ],
          _LabelField(
            label: AppLocalizations.of(context)!.tpProofOfDelivery,
            child: _UploadField(
              key: ValueKey('delivery-pod-${widget.stopIndex ?? 'single'}'),
              label: AppLocalizations.of(context)!.tpUploadPod,
              bidId: widget.bidId,
              stage: widget.stopIndex == null ? 'delivered' : 'delivered-stop',
              kind:
                  widget.stopIndex == null ? 'pod' : '${widget.stopIndex}-pod',
              initialPath: _podPhotoPath,
              onUploaded: (path) => _podPhotoPath = path,
            ),
          ),
          _LabelField(
            label: AppLocalizations.of(context)!.tpAdditionalChargesReason,
            child: PillTextField(
              controller: _billReason,
              hint: AppLocalizations.of(context)!.tpLoadingChargesHint,
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: AppLocalizations.of(context)!.tpBillPhoto,
            child: _UploadField(
              label: AppLocalizations.of(context)!.tpUploadBillPhoto,
              bidId: widget.bidId,
              stage: widget.stopIndex == null ? 'delivered' : 'delivered-stop',
              kind:
                  widget.stopIndex == null
                      ? 'bill'
                      : '${widget.stopIndex}-bill',
              initialPath: _billPhotoPath,
              onUploaded: (path) => _billPhotoPath = path,
            ),
          ),
          _LabelField(
            label: AppLocalizations.of(context)!.tpOnSitePhoto,
            child: _UploadField(
              label: AppLocalizations.of(context)!.tpUploadPresence,
              bidId: widget.bidId,
              stage: widget.stopIndex == null ? 'delivered' : 'delivered-stop',
              kind:
                  widget.stopIndex == null
                      ? 'site'
                      : '${widget.stopIndex}-site',
              initialPath: _sitePhotoPath,
              onUploaded: (path) => _sitePhotoPath = path,
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label:
                _saving
                    ? AppLocalizations.of(context)!.tpSavingEllipsis
                    : AppLocalizations.of(context)!.tpShareDelivery,
            onPressed:
                _saving
                    ? null
                    : () async {
                      if (_receiver.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.tpEnterReceiverName,
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() => _saving = true);
                      await _save(
                        context,
                        widget.bidId,
                        widget.stopIndex == null
                            ? 'delivered'
                            : 'delivered_stop',
                        {
                          if (widget.stopIndex != null)
                            'stop_index': widget.stopIndex,
                          if (widget.destination != null)
                            'destination': widget.destination,
                          'receiver_name': _receiver.text.trim(),
                          'receiver_phone': _receiverPhone.text.trim(),
                          if (widget.stopIndex == null) ...{
                            'gr_number': _gr.text.trim(),
                            'e_way_bill_number': _eWayBill.text.trim(),
                          } else ...{
                            'gr_numbers': _grNumbers,
                            'e_way_bill_numbers': _eWayBillNumbers,
                          },
                          'bill_reason': _billReason.text.trim(),
                          'pod_photo_path': _podPhotoPath,
                          'bill_photo_path': _billPhotoPath,
                          'site_photo_path': _sitePhotoPath,
                        },
                      );
                      if (mounted) setState(() => _saving = false);
                    },
          ),
        ],
      ),
    );
  }
}

List<String> _savedNumbers(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

bool _sameNumbers(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

class _ReferenceListField extends StatefulWidget {
  const _ReferenceListField({
    required this.label,
    required this.initialValues,
    required this.onChanged,
  });

  final String label;
  final List<String> initialValues;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ReferenceListField> createState() => _ReferenceListFieldState();
}

class _ReferenceListFieldState extends State<_ReferenceListField> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers =
        (widget.initialValues.isEmpty ? <String>[''] : widget.initialValues)
            .map(_controllerFor)
            .toList();
  }

  @override
  void didUpdateWidget(covariant _ReferenceListField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current =
        _controllers
            .map((controller) => controller.text.trim())
            .where((value) => value.isNotEmpty)
            .toList();
    if (_sameNumbers(current, oldWidget.initialValues) &&
        !_sameNumbers(oldWidget.initialValues, widget.initialValues)) {
      for (final controller in _controllers) {
        controller.removeListener(_notify);
        controller.dispose();
      }
      _controllers =
          (widget.initialValues.isEmpty ? <String>[''] : widget.initialValues)
              .map(_controllerFor)
              .toList();
    }
  }

  TextEditingController _controllerFor(String value) {
    final controller = TextEditingController(text: value);
    controller.addListener(_notify);
    return controller;
  }

  void _notify() {
    widget.onChanged(
      _controllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_notify);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LabelField(
      label: widget.label,
      child: Column(
        children: [
          for (final (index, controller) in _controllers.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: PillTextField(
                      controller: controller,
                      hint: '${widget.label} ${index + 1}',
                      textAlign: TextAlign.start,
                    ),
                  ),
                  if (_controllers.length > 1)
                    IconButton(
                      tooltip: AppLocalizations.of(
                        context,
                      )!.tpRemoveReference(widget.label),
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          final removed = _controllers.removeAt(index);
                          removed.removeListener(_notify);
                          removed.dispose();
                        });
                        _notify();
                      },
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  () => setState(() {
                    _controllers.add(_controllerFor(''));
                  }),
              icon: const Icon(Icons.add),
              label: Text(
                AppLocalizations.of(context)!.tpAddReference(widget.label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
