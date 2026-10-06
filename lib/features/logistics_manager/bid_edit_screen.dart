import 'widgets/operational_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/utils/bid_window.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/route_timeline.dart';
import 'widgets/transporter_audience_picker.dart';

const vehicleCapacityCategories = [
  'Up to 1 MT',
  'Up to 3 MT',
  '3-6 MT',
  '6-9 MT',
  '9-12 MT',
  '12-15 MT',
  '15+ MT',
];
const _automaticCapacitySelection = '__automatic_from_metric_tons__';

String inferVehicleCapacityCategory(double weightMt) {
  if (weightMt <= 1) return 'Up to 1 MT';
  if (weightMt <= 3) return 'Up to 3 MT';
  if (weightMt <= 6) return '3-6 MT';
  if (weightMt <= 9) return '6-9 MT';
  if (weightMt <= 12) return '9-12 MT';
  if (weightMt <= 15) return '12-15 MT';
  return '15+ MT';
}

bool shouldPreserveVehicleCapacityOverride({
  required String? storedCategory,
  required double currentWeightMt,
  bool? storedManualOverride,
}) {
  if (!vehicleCapacityCategories.contains(storedCategory)) return false;
  if (storedManualOverride != null) return storedManualOverride;
  return storedCategory != inferVehicleCapacityCategory(currentWeightMt);
}

class BidEditScreen extends StatefulWidget {
  const BidEditScreen({super.key, required this.bidId});
  final String bidId;

  @override
  State<BidEditScreen> createState() => _BidEditScreenState();
}

/// Keep the route used for delivery in the same order as the visible stops.
/// Existing quantities follow a stop by name when another stop is removed.
List<Map<String, dynamic>> buildStopDetailsForEditedRoute({
  required List<String> stops,
  required String destination,
  required List<dynamic> existingDetails,
}) {
  final existing =
      existingDetails
          .whereType<Map>()
          .map((detail) => Map<String, dynamic>.from(detail))
          .toList();
  final intermediate =
      existing.where((detail) => detail['kind'] != 'destination').toList();
  final used = <int>{};
  final result = <Map<String, dynamic>>[];

  for (final stop in stops) {
    final name = stop.trim();
    if (name.isEmpty) continue;
    var match = -1;
    for (var index = 0; index < intermediate.length; index++) {
      if (!used.contains(index) &&
          (intermediate[index]['name'] ?? '').toString().trim().toLowerCase() ==
              name.toLowerCase()) {
        match = index;
        break;
      }
    }
    if (match >= 0) used.add(match);
    final detail =
        match >= 0
            ? Map<String, dynamic>.from(intermediate[match])
            : <String, dynamic>{};
    detail['name'] = name;
    detail.remove('kind');
    result.add(detail);
  }

  final finalName = destination.trim();
  if (finalName.isNotEmpty) {
    final finalDetail = existing.lastWhere(
      (detail) => detail['kind'] == 'destination',
      orElse:
          () => existing.lastWhere(
            (detail) =>
                (detail['name'] ?? '').toString().trim().toLowerCase() ==
                finalName.toLowerCase(),
            orElse: () => <String, dynamic>{},
          ),
    );
    result.add({...finalDetail, 'name': finalName, 'kind': 'destination'});
  }
  return result;
}

({int cases, double weight}) editedRouteTotals(
  List<Map<String, dynamic>> details,
) {
  var cases = 0;
  var weight = 0.0;
  for (final detail in details) {
    cases += (detail['cases'] as num).toInt();
    weight += (detail['weight_kg'] as num).toDouble();
  }
  return (cases: cases, weight: weight);
}

class _StopQuantityDraft {
  _StopQuantityDraft({String cases = '', String weight = ''})
    : cases = TextEditingController(text: cases),
      weight = TextEditingController(text: weight);

  final TextEditingController cases;
  final TextEditingController weight;
  VoidCallback? _weightListener;

  void watchWeight(VoidCallback listener) {
    final previous = _weightListener;
    if (previous != null) weight.removeListener(previous);
    _weightListener = listener;
    weight.addListener(listener);
  }

  void load(Map<String, dynamic> detail) {
    cases.text = (detail['cases'] ?? '').toString();
    weight.text = (detail['weight_kg'] ?? '').toString();
  }

  ({int cases, double weight})? read() {
    final caseText = cases.text.trim();
    final weightText = weight.text.trim();
    if (caseText.isEmpty || weightText.isEmpty) return null;
    final count = int.tryParse(caseText);
    final tonnes = double.tryParse(weightText);
    if (count == null ||
        count < 0 ||
        tonnes == null ||
        !tonnes.isFinite ||
        tonnes < 0) {
      return null;
    }
    return (cases: count, weight: tonnes);
  }

  void dispose() {
    final listener = _weightListener;
    if (listener != null) weight.removeListener(listener);
    cases.dispose();
    weight.dispose();
  }
}

class _BidEditScreenState extends State<BidEditScreen> {
  final _stopController = TextEditingController();
  final _newStopCases = TextEditingController();
  final _newStopWeight = TextEditingController();
  final List<String> _stops = [];
  final List<_StopQuantityDraft> _stopQuantities = [];
  final _finalQuantity = _StopQuantityDraft();
  final List<Map<String, dynamic>> _stopDetails = [];
  String _origin = '';
  String _destination = '';
  String? _vehicleCapacityCategory;
  bool _vehicleCapacityEdited = false;
  DateTime? _closesAt;
  String? _status;

  List<Map<String, dynamic>> _transporters = [];
  final Set<String> _preferred = {};
  final Set<String> _blocked = {};
  bool _selectedOnly = false;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _finalQuantity.watchWeight(_refreshAutomaticCapacity);
    _load();
  }

  @override
  void dispose() {
    _stopController.dispose();
    _newStopCases.dispose();
    _newStopWeight.dispose();
    for (final quantity in _stopQuantities) {
      quantity.dispose();
    }
    _finalQuantity.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f =
          await supabase
              .from('freights')
              .select(
                'origin, destination_town, bid_closes_at, stops, stop_details, status, vehicle_capacity_category',
              )
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
        _closesAt = bidTimestamp(f['bid_closes_at'])?.toLocal();
        _status = f['status'] as String?;
        _origin = (f['origin'] ?? '').toString();
        _destination = (f['destination_town'] ?? '').toString();
        final list = (f['stops'] as List?) ?? const [];
        _stops
          ..clear()
          ..addAll(list.map((e) => e.toString()));
        _stopDetails
          ..clear()
          ..addAll(
            (f['stop_details'] as List? ?? const []).whereType<Map>().map(
              (detail) => Map<String, dynamic>.from(detail),
            ),
          );
        final ordered = buildStopDetailsForEditedRoute(
          stops: _stops,
          destination: _destination,
          existingDetails: _stopDetails,
        );
        final initialWeightMt = ordered.fold<double>(0, (total, detail) {
          final weight = num.tryParse('${detail['weight_kg'] ?? ''}');
          return total + (weight?.toDouble() ?? 0);
        });
        final storedCategory =
            (f['vehicle_capacity_category'] ?? '').toString();
        final storedManualOverride =
            ordered.isNotEmpty &&
                    ordered.last['vehicle_capacity_manual_override'] is bool
                ? ordered.last['vehicle_capacity_manual_override'] as bool
                : null;
        _vehicleCapacityEdited = shouldPreserveVehicleCapacityOverride(
          storedCategory: storedCategory,
          currentWeightMt: initialWeightMt,
          storedManualOverride: storedManualOverride,
        );
        _vehicleCapacityCategory =
            _vehicleCapacityEdited
                ? storedCategory
                : inferVehicleCapacityCategory(initialWeightMt);
        for (final quantity in _stopQuantities) {
          quantity.dispose();
        }
        _stopQuantities
          ..clear()
          ..addAll(
            ordered.take(_stops.length).map((detail) {
              final quantity = _StopQuantityDraft()..load(detail);
              quantity.watchWeight(_refreshAutomaticCapacity);
              return quantity;
            }),
          );
        if (ordered.length > _stops.length) {
          _finalQuantity.load(ordered.last);
        }
        _transporters = ts.cast<Map<String, dynamic>>();
        _preferred
          ..clear()
          ..addAll(prefs.map((r) => r['transporter_id'] as String));
        _blocked
          ..clear()
          ..addAll(blks.map((r) => r['transporter_id'] as String));
        _selectedOnly = _preferred.isNotEmpty;
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
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
    );
    if (t == null) return;
    setState(() {
      _closesAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void _addStop() {
    if (_status != 'bidding') return;
    final v = _stopController.text.trim();
    if (v.isEmpty) return;
    final quantity = _StopQuantityDraft(
      cases: _newStopCases.text,
      weight: _newStopWeight.text,
    );
    quantity.watchWeight(_refreshAutomaticCapacity);
    if (quantity.read() == null) {
      quantity.dispose();
      _showQuantityError();
      return;
    }
    if (_stops.any((stop) => stop.toLowerCase() == v.toLowerCase()) ||
        _destination.toLowerCase() == v.toLowerCase()) {
      quantity.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.opsDuplicateDeliveryDestination,
          ),
        ),
      );
      return;
    }
    setState(() {
      _stops.add(v);
      _stopQuantities.add(quantity);
      _stopController.clear();
      _newStopCases.clear();
      _newStopWeight.clear();
    });
    _refreshAutomaticCapacity();
  }

  double? _currentWeightMt() {
    final quantities = [..._stopQuantities, _finalQuantity];
    var total = 0.0;
    for (final quantity in quantities) {
      final weight = double.tryParse(quantity.weight.text.trim());
      if (weight == null || !weight.isFinite || weight < 0) return null;
      total += weight;
    }
    return total;
  }

  void _refreshAutomaticCapacity() {
    if (!mounted || _loading || _vehicleCapacityEdited) return;
    final totalWeight = _currentWeightMt();
    if (totalWeight == null) return;
    final category = inferVehicleCapacityCategory(totalWeight);
    if (_vehicleCapacityCategory == category) return;
    setState(() => _vehicleCapacityCategory = category);
  }

  void _selectVehicleCapacity(String? selection) {
    if (selection == null) return;
    if (selection == _automaticCapacitySelection) {
      final totalWeight = _currentWeightMt();
      setState(() {
        _vehicleCapacityEdited = false;
        if (totalWeight != null) {
          _vehicleCapacityCategory = inferVehicleCapacityCategory(totalWeight);
        }
      });
      return;
    }
    setState(() {
      _vehicleCapacityEdited = true;
      _vehicleCapacityCategory = selection;
    });
  }

  void _showQuantityError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.opsEnterDeliveryQuantities),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_status != 'bidding') return;
    if (_status == 'bidding' && _selectedOnly && _preferred.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.opsChooseAtLeastOneTransporter,
          ),
        ),
      );
      return;
    }
    final quantities =
        _stopQuantities.map((quantity) => quantity.read()).toList();
    final finalQuantity = _finalQuantity.read();
    if (quantities.contains(null) || finalQuantity == null) {
      _showQuantityError();
      return;
    }
    final details = buildStopDetailsForEditedRoute(
      stops: _stops,
      destination: _destination,
      existingDetails: _stopDetails,
    );
    for (var index = 0; index < _stops.length; index++) {
      details[index]['cases'] = quantities[index]!.cases;
      details[index]['weight_kg'] = quantities[index]!.weight;
    }
    details.last['cases'] = finalQuantity.cases;
    details.last['weight_kg'] = finalQuantity.weight;
    final totals = editedRouteTotals(details);
    final effectiveCapacityCategory =
        _vehicleCapacityCategory ?? inferVehicleCapacityCategory(totals.weight);
    details.last['vehicle_capacity_manual_override'] = _vehicleCapacityEdited;
    final bidAwardedDuringEdit =
        AppLocalizations.of(context)!.opsBidAwardedDuringEdit;
    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{
        'stops': _stops,
        'stop_details': details,
        'cases': totals.cases,
        'weight_kg': totals.weight,
        'vehicle_capacity_category': effectiveCapacityCategory,
      };
      if (_status == 'bidding' && _closesAt != null) {
        update['bid_closes_at'] = bidTimestampForDatabase(_closesAt!);
      }
      final updated = await supabase
          .from('freights')
          .update(update)
          .eq('id', widget.bidId)
          .eq('status', 'bidding')
          .select('id');
      if (updated.isEmpty) {
        throw StateError(bidAwardedDuringEdit);
      }

      // Rewrite preferred + blocked — simpler than diff'ing.
      await supabase
          .from('freight_preferred_transporters')
          .delete()
          .eq('freight_id', widget.bidId);
      if (_selectedOnly && _preferred.isNotEmpty) {
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
      if (!_selectedOnly && _blocked.isNotEmpty) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.opsSaved)),
      );
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

  Widget _stopQuantityCard(
    String name,
    _StopQuantityDraft quantity, {
    VoidCallback? onDelete,
    bool finalDestination = false,
  }) {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  finalDestination ? '${l.opsFinalDestination}: $name' : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: l.opsRemoveDestination,
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          if (_status == 'bidding') ...[
            const SizedBox(height: 8),
            OperationalFields(
              children: [
                Expanded(
                  child: PillTextField(
                    controller: quantity.cases,
                    hint:
                        finalDestination
                            ? l.opsDestinationCases
                            : l.opsStopCases,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PillTextField(
                    controller: quantity.weight,
                    hint: l.opsStopMetricTon,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              '${quantity.cases.text.isEmpty ? '—' : quantity.cases.text} ${l.opsCases} · '
              '${quantity.weight.text.isEmpty ? '—' : quantity.weight.text} ${l.opsMetricTons}',
              style: const TextStyle(color: Color(0xFF49454F)),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · '
      '${format12HourTime(d)}';

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
        title: Text(AppLocalizations.of(context)!.opsEditRequirement),
      ),
      body:
          _loading
              ? Center(child: CircularProgressIndicator())
              : OperationalListView(
                padding: const EdgeInsets.all(16),
                children: [
                  WorkspaceHeader(
                    title: operationalCopy(
                      context,
                      'Update transport request',
                      'परिवहन अनुरोध बदलें',
                    ),
                    description: operationalCopy(
                      context,
                      'Review the route, load and quoting window. Fields that are fixed after award remain protected.',
                      'मार्ग, माल और बोली का समय जाँचें। सौंपे जाने के बाद तय विवरण सुरक्षित रहते हैं।',
                    ),
                    icon: Icons.edit_road_outlined,
                  ),
                  OperationalStep(
                    '1',
                    operationalCopy(context, 'Quoting window', 'बोली का समय'),
                    operationalCopy(
                      context,
                      'Choose when quoting closes while this request is open.',
                      'अनुरोध खुला होने पर बोली बंद होने का समय चुनें।',
                    ),
                  ),
                  if (_status == 'bidding') ...[
                    Text(
                      AppLocalizations.of(context)!.opsExtendWindow,
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
                        child: OperationalFields(
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
                  OperationalStep(
                    '2',
                    operationalCopy(context, 'Route and load', 'मार्ग और माल'),
                    operationalCopy(
                      context,
                      'Confirm each destination and its allocated cases / MT.',
                      'हर गंतव्य और उसकी केस / MT मात्रा की पुष्टि करें।',
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.opsStopsInBetween,
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
                      child: Column(
                        children:
                            _stops
                                .asMap()
                                .entries
                                .map(
                                  (e) => _stopQuantityCard(
                                    e.value,
                                    _stopQuantities[e.key],
                                    onDelete:
                                        _status == 'bidding'
                                            ? () {
                                              final removed =
                                                  _stopQuantities[e.key];
                                              setState(() {
                                                _stops.removeAt(e.key);
                                                _stopQuantities.removeAt(e.key);
                                              });
                                              _refreshAutomaticCapacity();
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback(
                                                    (_) => removed.dispose(),
                                                  );
                                            }
                                            : null,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  if (_status == 'bidding')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PillTextField(
                          controller: _stopController,
                          hint: 'Add a stop and tap +',
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 8),
                        OperationalFields(
                          children: [
                            Expanded(
                              child: PillTextField(
                                controller: _newStopCases,
                                hint:
                                    AppLocalizations.of(context)!.opsStopCases,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: PillTextField(
                                controller: _newStopWeight,
                                hint:
                                    AppLocalizations.of(
                                      context,
                                    )!.opsStopMetricTon,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
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
                  if (_status == 'bidding')
                    _stopQuantityCard(
                      _destination,
                      _finalQuantity,
                      finalDestination: true,
                    ),
                  if (_status == 'bidding') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey((
                        _vehicleCapacityEdited,
                        _vehicleCapacityCategory,
                      )),
                      initialValue:
                          _vehicleCapacityEdited
                              ? _vehicleCapacityCategory
                              : _automaticCapacitySelection,
                      decoration: const InputDecoration(
                        labelText: 'Expected vehicle capacity',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: _automaticCapacitySelection,
                          child: Text(
                            'Automatic from MT · ${_vehicleCapacityCategory ?? '—'}',
                          ),
                        ),
                        ...vehicleCapacityCategories.map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        ),
                      ],
                      onChanged: _selectVehicleCapacity,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_status == 'bidding') ...[
                    OperationalStep(
                      '3',
                      operationalCopy(
                        context,
                        'Who can quote',
                        'कौन बोली लगा सकता है',
                      ),
                      operationalCopy(
                        context,
                        'Choose the approved transporters who will see this request.',
                        'स्वीकृत ट्रांसपोर्टर चुनें जिन्हें यह अनुरोध दिखेगा।',
                      ),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: TransporterAudiencePicker(
                          transporters: _transporters,
                          selectedOnly: _selectedOnly,
                          selectedIds: _preferred,
                          excludedIds: _blocked,
                          onModeChanged:
                              (selectedOnly) => setState(() {
                                _selectedOnly = selectedOnly;
                                _preferred.clear();
                                _blocked.clear();
                              }),
                          onTransporterChanged:
                              (id, checked) => setState(() {
                                final target =
                                    _selectedOnly ? _preferred : _blocked;
                                if (checked) {
                                  target.add(id);
                                } else {
                                  target.remove(id);
                                }
                              }),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_status == 'bidding')
                    PrimaryButton(
                      label:
                          _saving
                              ? AppLocalizations.of(context)!.opsSaving
                              : AppLocalizations.of(context)!.opsSaveChanges,
                      onPressed: _saving ? null : _save,
                    ),
                ],
              ),
    );
  }
}
