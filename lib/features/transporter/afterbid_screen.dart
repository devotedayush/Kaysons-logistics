import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/india_city_field.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/storage_photo_viewer.dart';

class AfterbidScreen extends StatelessWidget {
  const AfterbidScreen({super.key, required this.bidId});

  final String bidId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: FreightsRepo.instance.streamFreight(bidId),
          builder: (context, snap) {
            final freight = snap.data;
            if (freight == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final stages = Map<String, dynamic>.from(
              freight['delivery_stages'] as Map? ?? {},
            );
            final route =
                '${freight['origin']} → ${freight['destination_town']}';
            final progressLabel = _progressLabel(freight, stages);
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(context, route: route),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    progressLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF1D1B20),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Delivery progress',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 8),
                _DispatchedPanel(bidId: bidId, saved: stages['dispatched']),
                _LmVehicleConfirmationBanner(stages: stages),
                _PickupPanel(bidId: bidId, saved: stages['pickup']),
                _InTransitPanel(bidId: bidId, saved: stages['in_transit']),
                _DeliveredPanel(bidId: bidId, saved: stages['delivered']),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  String _progressLabel(
    Map<String, dynamic> freight,
    Map<String, dynamic> stages,
  ) {
    if (stages.containsKey('delivered')) return 'DELIVERED';
    if (stages.containsKey('in_transit')) return 'IN TRANSIT';
    if (stages.containsKey('pickup')) return 'PICKUP';
    if (stages.containsKey('dispatched')) return 'DISPATCHED';
    return (freight['status'] as String? ?? '').toUpperCase();
  }

  Widget _header(BuildContext context, {required String route}) {
    return Stack(
      children: [
        Container(
          height: 200,
          decoration: const BoxDecoration(
            color: Color(0xFFECE6F0),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: const Center(
            child: Icon(
              Icons.local_shipping_outlined,
              size: 96,
              color: Color(0xFFB39DC8),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE8DEF8),
            ),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Text(
            route,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LmVehicleConfirmationBanner extends StatelessWidget {
  const _LmVehicleConfirmationBanner({required this.stages});

  final Map<String, dynamic> stages;

  @override
  Widget build(BuildContext context) {
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
                      ? 'LM confirmed vehicle'
                      : issue
                      ? 'LM raised an issue'
                      : 'Waiting for LM vehicle confirmation',
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
                      ? 'The logistics manager has confirmed the vehicle details.'
                      : issue
                      ? 'Update the dispatch details and submit again for confirmation.'
                      : 'If you change dispatch details, LM will need to confirm again.',
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
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
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
          const SnackBar(content: Text('Could not read selected image')),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo uploaded')));
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
                      ? 'Uploading...'
                      : uploaded
                      ? 'Uploaded - tap to preview'
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
    await FreightsRepo.instance.saveDeliveryStage(
      freightId: bidId,
      stage: stage,
      data: data,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
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
      title: 'Dispatched',
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
          const _SectionHeader('Lorry proof'),
          _LabelField(
            label: 'Add Lorry Photograph',
            child: _UploadField(
              label: 'Upload a photo of Lorry',
              bidId: widget.bidId,
              stage: 'dispatched',
              kind: 'lorry',
              initialPath: _lorryPhotoPath,
              onUploaded: (path) => _lorryPhotoPath = path,
            ),
          ),
          const SizedBox(height: 8),
          const _SectionHeader('Driver proof'),
          _LabelField(
            label: 'Enter Driver Photograph',
            child: _UploadField(
              label: 'Upload a photo of Driver',
              bidId: widget.bidId,
              stage: 'dispatched',
              kind: 'driver',
              initialPath: _driverPhotoPath,
              onUploaded: (path) => _driverPhotoPath = path,
            ),
          ),
          _LabelField(
            label: 'Enter Driver Aadhaar Card Photograph',
            child: _UploadField(
              label: 'Upload a photo of Driver Aadhaar Card',
              bidId: widget.bidId,
              stage: 'dispatched',
              kind: 'driver-aadhaar',
              initialPath: _driverAadhaarPath,
              onUploaded: (path) => _driverAadhaarPath = path,
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: _saving ? 'Saving…' : 'Submit Lorry details',
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
          title: 'Select vehicle',
          emptyText: 'No saved vehicles yet',
          selectedTitle:
              selected == null
                  ? 'Choose from your saved fleet'
                  : (selected['registration_number'] ?? 'Vehicle').toString(),
          selectedSubtitle:
              selected == null
                  ? 'Use a vehicle you already added, or add one first.'
                  : _vehicleSummary(selected),
          icon: Icons.local_shipping_outlined,
          addLabel: 'Add vehicle',
          selectLabel: vehicles.isEmpty ? null : 'Select vehicle',
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

  static String _vehicleSummary(Map<String, dynamic> vehicle) {
    final capacity = [
      if ((vehicle['capacity_qt'] ?? '').toString().trim().isNotEmpty)
        '${vehicle['capacity_qt']} QT',
      if ((vehicle['capacity_weight_kg'] ?? '').toString().trim().isNotEmpty)
        '${vehicle['capacity_weight_kg']} WT',
    ].join(' · ');
    return [
      (vehicle['vehicle_type'] ?? '').toString(),
      capacity,
      if ((vehicle['rc_number'] ?? '').toString().trim().isNotEmpty) 'RC saved',
      if ((vehicle['insurance_number'] ?? '').toString().trim().isNotEmpty)
        'Insurance saved',
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
            title: 'Select vehicle',
            rows: vehicles,
            icon: Icons.local_shipping_outlined,
            titleFor:
                (row) => (row['registration_number'] ?? 'Vehicle').toString(),
            subtitleFor: _vehicleSummary,
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
          title: 'Select driver',
          emptyText: 'No saved drivers yet',
          selectedTitle:
              selected == null
                  ? 'Choose from your saved drivers'
                  : (selected['name'] ?? 'Driver').toString(),
          selectedSubtitle:
              selected == null
                  ? 'Use a driver you already added, or add one first.'
                  : [
                    (selected['phone'] ?? '').toString(),
                    if ((selected['licence_number'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      'Licence saved',
                  ].where((value) => value.trim().isNotEmpty).join(' · '),
          icon: Icons.badge_outlined,
          addLabel: 'Add driver',
          selectLabel: drivers.isEmpty ? null : 'Select driver',
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
            title: 'Select driver',
            rows: drivers,
            icon: Icons.badge_outlined,
            titleFor: (row) => (row['name'] ?? 'Driver').toString(),
            subtitleFor:
                (row) => [
                  (row['phone'] ?? '').toString(),
                  if ((row['licence_number'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    'Licence saved',
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
  late final TextEditingController _invoice;
  late final TextEditingController _phone;
  String? _invoicePhotoPath;
  String? _sitePhotoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.saved as Map<String, dynamic>? ?? {};
    _invoice = TextEditingController(text: s['invoice_number'] ?? '');
    _phone = TextEditingController(text: s['driver_phone'] ?? '');
    _invoicePhotoPath = s['invoice_photo_path'] as String?;
    _sitePhotoPath = s['site_photo_path'] as String?;
  }

  @override
  void dispose() {
    _invoice.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StagePanel(
      title: 'Pickup',
      submitted: widget.saved != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Add Bill details'),
          _LabelField(
            label: 'Enter Invoice number',
            child: PillTextField(
              controller: _invoice,
              hint: 'RM - MAR - 8765 - 600 - 1GG',
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'Enter Invoice Photograph',
            child: _UploadField(
              label: 'Upload a photo of Invoice',
              bidId: widget.bidId,
              stage: 'pickup',
              kind: 'invoice',
              initialPath: _invoicePhotoPath,
              onUploaded: (path) => _invoicePhotoPath = path,
            ),
          ),
          _LabelField(
            label: 'Enter Driver Phone Number',
            child: PillTextField(
              controller: _phone,
              hint: '987 - 6541 - 321',
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'Enter on site photo',
            child: _UploadField(
              label: 'Upload a photo of your presence',
              bidId: widget.bidId,
              stage: 'pickup',
              kind: 'site',
              initialPath: _sitePhotoPath,
              onUploaded: (path) => _sitePhotoPath = path,
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: _saving ? 'Saving…' : 'Submit Pickup details',
            onPressed:
                _saving
                    ? null
                    : () async {
                      setState(() => _saving = true);
                      await _save(context, widget.bidId, 'pickup', {
                        'invoice_number': _invoice.text.trim(),
                        'driver_phone': _phone.text.trim(),
                        'invoice_photo_path': _invoicePhotoPath,
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
  const _InTransitPanel({required this.bidId, required this.saved});
  final String bidId;
  final dynamic saved;

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
      title: 'In Transit',
      submitted: widget.saved != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Sub-contractors'),
          ..._contractors.asMap().entries.map(
            (e) => _contractorCard(e.key, e.value),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _addContractor,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add contractor'),
          ),
          const SizedBox(height: 16),
          const _SectionHeader('Verification details'),
          _LabelField(
            label: 'GR / Bilty number',
            child: PillTextField(
              controller: _grBilty,
              hint: 'GR-7821',
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'E-way bill number',
            child: PillTextField(
              controller: _eWayBill,
              hint: 'EWB-1122334455',
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'Current location',
            child: PillTextField(
              controller: _lastLocation,
              hint: 'e.g. Ambala bypass',
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
                            const SnackBar(
                              content: Text('Enter the current location'),
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
                            const SnackBar(content: Text('Location updated')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Location update failed: $e'),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _savingLocation = false);
                          }
                        }
                      },
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(_savingLocation ? 'Updating...' : 'Update location'),
            ),
          ),
          const SizedBox(height: 10),
          if (_sitePhotoPath != null)
            _LabelField(
              label: 'Transit site photo',
              child: _UploadField(
                label: 'Upload a photo of your presence',
                bidId: widget.bidId,
                stage: 'in-transit',
                kind: 'site',
                initialPath: _sitePhotoPath,
                onUploaded: (path) => _sitePhotoPath = path,
              ),
            ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: _saving ? 'Saving…' : 'Share transit details',
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
                        'gr_bilty_number': _grBilty.text.trim(),
                        'e_way_bill_number': _eWayBill.text.trim(),
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
                  'Contractor ${i + 1}',
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
          _fieldRow('Name', c.name, (v) => c.name = v, 'Vijaypratap Rajput'),
          _fieldRow(
            'Phone',
            c.phone,
            (v) => c.phone = v,
            '987-6543-654',
            keyboardType: TextInputType.phone,
          ),
          Row(
            children: [
              Expanded(
                child: _fieldRow(
                  'From',
                  c.from,
                  (v) => c.from = v,
                  'Select city',
                  useCityPicker: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _fieldRow(
                  'To',
                  c.to,
                  (v) => c.to = v,
                  'Select city',
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
  const _DeliveredPanel({required this.bidId, required this.saved});
  final String bidId;
  final dynamic saved;

  @override
  State<_DeliveredPanel> createState() => _DeliveredPanelState();
}

class _DeliveredPanelState extends State<_DeliveredPanel> {
  late final TextEditingController _receiver;
  late final TextEditingController _receiverPhone;
  late final TextEditingController _gr;
  late final TextEditingController _eWayBill;
  late final TextEditingController _billReason;
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
    _podPhotoPath = s['pod_photo_path'] as String?;
    _billPhotoPath = s['bill_photo_path'] as String?;
    _sitePhotoPath = s['site_photo_path'] as String?;
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
      title: 'Delivered',
      submitted: widget.saved != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Enter Delivery site details'),
          _LabelField(
            label: 'Enter receiver name',
            child: PillTextField(
              controller: _receiver,
              hint: 'Vijaypratap Rajput',
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'Enter Receiver number',
            child: PillTextField(
              controller: _receiverPhone,
              hint: '987-6543-654',
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'Enter GR Number',
            child: PillTextField(
              controller: _gr,
              hint: 'GR-4521',
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'Enter E-way Bill Number',
            child: PillTextField(
              controller: _eWayBill,
              hint: 'EWB-1122334455',
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'Proof of Delivery (GR)',
            child: _UploadField(
              label: 'Upload Proof of Delivery',
              bidId: widget.bidId,
              stage: 'delivered',
              kind: 'pod',
              initialPath: _podPhotoPath,
              onUploaded: (path) => _podPhotoPath = path,
            ),
          ),
          _LabelField(
            label: 'Additional Charges (if any) — bill reason',
            child: PillTextField(
              controller: _billReason,
              hint: 'e.g. loading charges',
              textAlign: TextAlign.start,
            ),
          ),
          _LabelField(
            label: 'Bill photo',
            child: _UploadField(
              label: 'Upload a photo of the bill',
              bidId: widget.bidId,
              stage: 'delivered',
              kind: 'bill',
              initialPath: _billPhotoPath,
              onUploaded: (path) => _billPhotoPath = path,
            ),
          ),
          _LabelField(
            label: 'On-site photo',
            child: _UploadField(
              label: 'Upload a photo of your presence',
              bidId: widget.bidId,
              stage: 'delivered',
              kind: 'site',
              initialPath: _sitePhotoPath,
              onUploaded: (path) => _sitePhotoPath = path,
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: _saving ? 'Saving…' : 'Share delivery details',
            onPressed:
                _saving
                    ? null
                    : () async {
                      setState(() => _saving = true);
                      await _save(context, widget.bidId, 'delivered', {
                        'receiver_name': _receiver.text.trim(),
                        'receiver_phone': _receiverPhone.text.trim(),
                        'gr_number': _gr.text.trim(),
                        'e_way_bill_number': _eWayBill.text.trim(),
                        'bill_reason': _billReason.text.trim(),
                        'pod_photo_path': _podPhotoPath,
                        'bill_photo_path': _billPhotoPath,
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
