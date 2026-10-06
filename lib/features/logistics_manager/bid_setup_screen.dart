import 'widgets/operational_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/utils/bid_window.dart';
import '../../core/widgets/india_city_field.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/route_timeline.dart';
import 'widgets/transporter_audience_picker.dart';

const _vehicleCapacityCategories = [
  'Up to 1 MT',
  'Up to 3 MT',
  '3-6 MT',
  '6-9 MT',
  '9-12 MT',
  '12-15 MT',
  '15+ MT',
];

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
  bool _selectedOnly = false;
  bool _publishing = false;
  bool _vehicleCapacityEdited = false;
  String? _vehicleCapacityCategory;

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
    if (!mounted) return;
    setState(() {
      if (!_vehicleCapacityEdited) _vehicleCapacityCategory = null;
    });
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
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
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
      if (!_vehicleCapacityEdited) _vehicleCapacityCategory = null;
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
        meta: '${stop.cases} Cases · ${formatMetricTons(stop.weightKg)} MT',
      ),
    ),
    RoutePoint(
      label: _to.text.trim(),
      kind: RoutePointKind.destination,
      meta:
          '${int.tryParse(_cases.text.trim()) ?? 0} Cases · '
          '${formatMetricTons(double.tryParse(_weight.text.trim()) ?? 0)} MT',
    ),
  ];

  Future<void> _publish() async {
    if (_publishing) return;
    if (_from.text.trim().isEmpty || _to.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.opsFromToRequired),
        ),
      );
      return;
    }
    if (!_isBid && _assignTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.opsPickTransporter),
        ),
      );
      return;
    }
    if (_isBid && _selectedOnly && _preferred.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.opsChooseAtLeastOneTransporter,
          ),
        ),
      );
      return;
    }
    final baseFreight = _parseAmount(_baseFreight);
    final callingBid = _parseAmount(_internalCallingBid);
    final hasInvalidAmount =
        (_baseFreight.text.trim().isNotEmpty && baseFreight == null) ||
        (_internalCallingBid.text.trim().isNotEmpty && callingBid == null);
    if (hasInvalidAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.opsAmountsValid)),
      );
      return;
    }
    if ((baseFreight != null && baseFreight <= 0) ||
        (callingBid != null && callingBid <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.opsAmountsPositive),
        ),
      );
      return;
    }
    if (!_isBid && (baseFreight == null || baseFreight <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.opsAgreedFreightPositive),
        ),
      );
      return;
    }
    if (_isBid && !_closesAt.isAfter(_opensAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.opsCloseAfterOpen),
        ),
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
        'vehicle_capacity_category':
            _vehicleCapacityCategory ??
            _suggestVehicleCapacityCategory(_totalWeight),
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

      // The schema has one freight-level reference amount. Preserve the base
      // freight field even when the optional calling-bid field is blank.
      final referenceFreight = callingBid ?? baseFreight;
      if (referenceFreight != null) {
        payload['internal_calling_bid'] = referenceFreight;
      }

      if (_isBid) {
        payload.addAll({
          'bid_opens_at': bidTimestampForDatabase(_opensAt),
          'bid_closes_at': bidTimestampForDatabase(_closesAt),
          'status': 'bidding',
        });
      } else {
        payload.addAll({
          // Direct assignment has no transporter bid row to award. Persist
          // its agreed amount with the winner in the same freight insert.
          'status': 'awarded',
          'winner_profile_id': _assignTo,
          'accepted_freight_amount': baseFreight,
        });
      }

      final freight =
          await supabase.from('freights').insert(payload).select('id').single();
      final freightId = freight['id'] as String;

      if (_isBid && _selectedOnly) {
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
      if (_isBid && !_selectedOnly && _blocked.isNotEmpty) {
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

  double? _parseAmount(TextEditingController controller) {
    final raw = controller.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    final amount = double.tryParse(raw);
    return amount != null && amount.isFinite ? amount : null;
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · '
      '${format12HourTime(d)}';

  @override
  Widget build(BuildContext context) {
    final capacityValue =
        _vehicleCapacityCategory ??
        _suggestVehicleCapacityCategory(_totalWeight);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(AppLocalizations.of(context)!.opsNewRequirement),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: OperationalListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              WorkspaceHeader(
                title: operationalCopy(
                  context,
                  'Create a transport request',
                  'परिवहन अनुरोध बनाएँ',
                ),
                description: operationalCopy(
                  context,
                  'Add the route and load, choose who can quote, then review before publishing.',
                  'मार्ग और माल जोड़ें, ट्रांसपोर्टर चुनें और प्रकाशित करने से पहले जाँचें।',
                ),
                icon: Icons.add_road_outlined,
              ),
              OperationalStep(
                '1',
                operationalCopy(
                  context,
                  'Route and delivery quantities',
                  'मार्ग और डिलीवरी मात्रा',
                ),
                operationalCopy(
                  context,
                  'Enter the pickup city, each delivery stop and the cases / MT for that stop.',
                  'पिकअप शहर, हर डिलीवरी पड़ाव और उसकी केस / MT मात्रा भरें।',
                ),
              ),
              _labeled(
                AppLocalizations.of(context)!.opsFrom,
                IndiaCityField(
                  controller: _from,
                  hint: 'Hoshiarpur',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              OperationalOptional(
                title: operationalCopy(
                  context,
                  'Add intermediate delivery stops',
                  'बीच के डिलीवरी पड़ाव जोड़ें',
                ),
                initiallyExpanded: _stops.isNotEmpty,
                children: [
                  // Stops
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.opsStopsOptional,
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
                                      color: const Color(0xFFF3F5FA),
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
                                          '${e.value.cases} Cases · ${formatMetricTons(e.value.weightKg)} MT',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF49454F),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => setState(() {
                                                _stops.removeAt(e.key);
                                                if (!_vehicleCapacityEdited) {
                                                  _vehicleCapacityCategory =
                                                      null;
                                                }
                                              }),
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
                        hint: AppLocalizations.of(context)!.opsStopCity,
                      ),
                      const SizedBox(height: 8),
                      OperationalFields(
                        children: [
                          Expanded(
                            child: PillTextField(
                              controller: _stopCases,
                              hint: AppLocalizations.of(context)!.opsStopCases,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PillTextField(
                              controller: _stopWeight,
                              hint:
                                  AppLocalizations.of(
                                    context,
                                  )!.opsStopMetricTon,
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
                ],
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.opsFinalDestination,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF49454F),
                ),
              ),
              const SizedBox(height: 6),
              IndiaCityField(
                controller: _to,
                hint: AppLocalizations.of(context)!.opsDestinationCity,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              OperationalFields(
                children: [
                  Expanded(
                    child: PillTextField(
                      controller: _cases,
                      hint: AppLocalizations.of(context)!.opsDestinationCases,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PillTextField(
                      controller: _weight,
                      hint:
                          AppLocalizations.of(context)!.opsDestinationMetricTon,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
              _TotalQuantityCard(cases: _totalCases, weight: _totalWeight),
              OperationalStep(
                '2',
                operationalCopy(context, 'Vehicle and price', 'वाहन और कीमत'),
                operationalCopy(
                  context,
                  'Check total load and expected capacity before setting the freight amount.',
                  'किराया तय करने से पहले कुल माल और वाहन क्षमता जाँचें।',
                ),
              ),
              _VehicleCapacityPicker(
                value: capacityValue,
                onChanged:
                    (value) => setState(() {
                      _vehicleCapacityCategory = value;
                      _vehicleCapacityEdited = true;
                    }),
              ),
              RouteTimeline(points: _routePoints),
              const SizedBox(height: 14),
              _labeled(
                AppLocalizations.of(context)!.opsBaseFreight,
                PillTextField(
                  controller: _baseFreight,
                  hint: '6500',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.start,
                ),
              ),
              const Divider(height: 28),
              OperationalStep(
                '3',
                operationalCopy(
                  context,
                  'Choose the transporter',
                  'ट्रांसपोर्टर चुनें',
                ),
                operationalCopy(
                  context,
                  'Invite quotes during a bidding window, or assign this request directly.',
                  'बोली के लिए समय तय करें या यह अनुरोध सीधे सौंपें।',
                ),
              ),
              SwitchListTile(
                value: _isBid,
                onChanged: (v) => setState(() => _isBid = v),
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocalizations.of(context)!.opsOpenForBidding),
                subtitle: Text(
                  _isBid
                      ? AppLocalizations.of(context)!.opsCompeteUntilClose
                      : AppLocalizations.of(context)!.opsAssignDirectlyHint,
                ),
              ),
              if (_isBid) ...[
                OperationalFields(
                  children: [
                    Expanded(
                      child: _DateTimeField(
                        label: AppLocalizations.of(context)!.opsOpensAt,
                        value: _fmtDateTime(_opensAt),
                        onTap: () => _pickDateTime(opens: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateTimeField(
                        label: AppLocalizations.of(context)!.opsClosesAt,
                        value: _fmtDateTime(_closesAt),
                        onTap: () => _pickDateTime(opens: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _labeled(
                  AppLocalizations.of(context)!.opsInternalCallingBid,
                  PillTextField(
                    controller: _internalCallingBid,
                    hint: '15000',
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.start,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    AppLocalizations.of(context)!.opsReferencePriceHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TransporterAudiencePicker(
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
                        final target = _selectedOnly ? _preferred : _blocked;
                        if (checked) {
                          target.add(id);
                        } else {
                          target.remove(id);
                        }
                      }),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.opsAssignToTransporter,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _transporterPicker(),
              ],
              const SizedBox(height: 24),
              if (_isBid) ...[_reviewCard(context), const SizedBox(height: 18)],
              OperationalStep(
                '4',
                operationalCopy(
                  context,
                  'Review and publish',
                  'जाँचें और प्रकाशित करें',
                ),
                operationalCopy(
                  context,
                  'Check the route, quantities, price and selected transporters above.',
                  'ऊपर मार्ग, मात्रा, किराया और चुने हुए ट्रांसपोर्टर जाँचें।',
                ),
              ),
              PrimaryButton(
                label:
                    _publishing
                        ? 'Publishing…'
                        : (_isBid
                            ? AppLocalizations.of(context)!.opsPublishBid
                            : AppLocalizations.of(context)!.opsAssignDispatch),
                onPressed: _publishing ? null : _publish,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewCard(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final audience =
        _selectedOnly
            ? l.opsSelectedCount(_preferred.length)
            : '${l.opsAllApprovedTransporters} · '
                '${l.opsExcludedCount(_blocked.length)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.opsReviewAndPublish,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('${l.opsVisibleTo}: $audience'),
          Text('${l.opsBidCloses}: ${_fmtDateTime(_closesAt)}'),
        ],
      ),
    );
  }

  Widget _transporterPicker() {
    if (_transporters.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          AppLocalizations.of(context)!.opsNoApprovedTransporters,
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
            final selected = _assignTo == id;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected:
                  (v) => setState(() {
                    _assignTo = v ? id : null;
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

class _VehicleCapacityPicker extends StatelessWidget {
  const _VehicleCapacityPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: 'Vehicle capacity',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        items:
            _vehicleCapacityCategories
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
        onChanged: onChanged,
      ),
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
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.opsTotalRequirement,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$cases Cases · ${formatMetricTons(weight)} MT',
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

String _suggestVehicleCapacityCategory(double weightMt) {
  if (weightMt <= 1) return 'Up to 1 MT';
  if (weightMt <= 3) return 'Up to 3 MT';
  if (weightMt <= 6) return '3-6 MT';
  if (weightMt <= 9) return '6-9 MT';
  if (weightMt <= 12) return '9-12 MT';
  if (weightMt <= 15) return '12-15 MT';
  return '15+ MT';
}
