import 'widgets/operational_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bid_window.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/widgets/bid_window_countdown.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/route_timeline.dart';

class BidManagementScreen extends StatefulWidget {
  const BidManagementScreen({
    super.key,
    required this.bidId,
    this.adminMode = false,
  });

  final String bidId;
  final bool adminMode;

  @override
  State<BidManagementScreen> createState() => _BidManagementScreenState();
}

class _BidManagementScreenState extends State<BidManagementScreen> {
  Map<String, dynamic>? _freight;
  String? _selectedTransporterId;
  String? _selectedLabel;
  bool _awarding = false;

  @override
  void initState() {
    super.initState();
    _loadFreight();
  }

  Future<void> _loadFreight() async {
    final f = await FreightsRepo.instance.fetchFreight(widget.bidId);
    if (!mounted) return;
    setState(() => _freight = f);
  }

  @override
  Widget build(BuildContext context) {
    final freight = _freight;
    final route =
        freight == null
            ? 'Loading...'
            : '${freight['origin']} → ${freight['destination_town']}';
    final status = freight?['status'] ?? '';
    final alreadyAwarded = status != 'bidding';
    final routePoints =
        freight == null ? const <RoutePoint>[] : _routePointsFor(freight);
    final opensAt = bidTimestamp(freight?['bid_opens_at']);
    final closesAt = bidTimestamp(freight?['bid_closes_at']);
    final closeAt = closesAt?.toLocal();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Bid ${widget.bidId.substring(0, 6)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: AppLocalizations.of(context)!.opsEditStopsWindow,
            onPressed:
                () => context.push(
                  '${widget.adminMode ? '/admin' : '/lm'}/bid/${widget.bidId}/edit',
                ),
          ),
        ],
      ),
      body:
          freight == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: OperationalListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      WorkspaceHeader(
                        title: operationalCopy(
                          context,
                          'Compare transporter quotes',
                          'ट्रांसपोर्टर बोलियों की तुलना करें',
                        ),
                        description: operationalCopy(
                          context,
                          'Review the route and prices. Select one transporter, then confirm the award.',
                          'मार्ग और कीमतें जाँचें। एक ट्रांसपोर्टर चुनें और फिर पुष्टि करें।',
                        ),
                        icon: Icons.compare_arrows,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FC),
                          border: Border.all(color: const Color(0xFFE1DAE8)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route,
                              style: const TextStyle(
                                fontSize: 26,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D1B20),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (status == 'bidding') ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F5FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      color: Color(0xFF4F378A),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: BidWindowCountdown(
                                        status: status.toString(),
                                        opensAt: opensAt,
                                        closesAt: closesAt,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4F378A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _InfoPill(
                                  icon: Icons.inventory_2_outlined,
                                  label: '${freight['cases'] ?? 0} Cases',
                                ),
                                _InfoPill(
                                  icon: Icons.scale_outlined,
                                  label:
                                      '${formatMetricTons(freight['weight_kg'])} MT',
                                ),
                                _InfoPill(
                                  icon: Icons.circle,
                                  label: status.toString().toUpperCase(),
                                ),
                                if (closeAt != null)
                                  _InfoPill(
                                    icon: Icons.schedule,
                                    label:
                                        'Closes ${closeAt.day.toString().padLeft(2, '0')}/${closeAt.month.toString().padLeft(2, '0')}/${closeAt.year} · ${format12HourTime(closeAt)}',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            RouteTimeline(points: routePoints),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      OperationalStep(
                        '1',
                        operationalCopy(
                          context,
                          'Choose a quote',
                          'बोली चुनें',
                        ),
                        operationalCopy(
                          context,
                          'Compare the quoted freight and transporter details before choosing.',
                          'चुनने से पहले किराया और ट्रांसपोर्टर विवरण की तुलना करें।',
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.opsBiddersLive,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D1B20),
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: FreightsRepo.instance.streamBidsFor(
                          widget.bidId,
                        ),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final bids = snap.data!;
                          if (bids.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE1DAE8),
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.opsNoBidsReceived,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Color(0xFF49454F),
                                ),
                              ),
                            );
                          }
                          return FutureBuilder<Map<String, String>>(
                            future: _fetchBidderLabels(bids),
                            builder: (context, labelSnap) {
                              final labels = labelSnap.data ?? const {};
                              return Column(
                                children:
                                    bids.map((b) {
                                      final tid = b['transporter_id'] as String;
                                      final amount =
                                          (b['amount'] as num).toDouble();
                                      return _bidderRow(
                                        tid,
                                        labels[tid] ?? 'Transporter',
                                        amount,
                                        disabled: alreadyAwarded,
                                      );
                                    }).toList(),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      if (!alreadyAwarded && _selectedTransporterId != null)
                        _AwardPanel(
                          selectedLabel: _selectedLabel,
                          awarding: _awarding,
                          onConfirm: () async {
                            setState(() => _awarding = true);
                            try {
                              await FreightsRepo.instance.awardWinner(
                                freightId: widget.bidId,
                                winnerProfileId: _selectedTransporterId!,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Award failed: $e')),
                              );
                              if (mounted) setState(() => _awarding = false);
                              return;
                            }
                            if (!context.mounted) return;
                            setState(() => _awarding = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.opsWinnerConfirmed,
                                ),
                              ),
                            );
                            // A direct URL can render this page without a
                            // navigator entry. Treat navigation separately so
                            // a successful award is never reported as failed.
                            try {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(
                                  widget.adminMode ? '/admin/bids' : '/lm/bids',
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                context.go(
                                  widget.adminMode ? '/admin/bids' : '/lm/bids',
                                );
                              }
                            }
                          },
                        ),
                      if (alreadyAwarded)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F6EC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'This bid is $status.',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton.icon(
                                    onPressed:
                                        () => context.push(
                                          '${widget.adminMode ? '/admin' : '/lm'}/track/${widget.bidId}',
                                        ),
                                    icon: const Icon(
                                      Icons.local_shipping_outlined,
                                    ),
                                    label: Text(
                                      AppLocalizations.of(context)!.opsTrack,
                                    ),
                                  ),
                                  if (const {
                                    'awarded',
                                    'dispatched',
                                    'locked',
                                    'completed',
                                  }.contains(status))
                                    TextButton.icon(
                                      onPressed:
                                          () => context.push(
                                            '${widget.adminMode ? '/admin' : '/lm'}/bid/${widget.bidId}/invoice',
                                          ),
                                      icon: const Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                      label: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.opsLockInvoices,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }

  Future<Map<String, String>> _fetchBidderLabels(
    List<Map<String, dynamic>> bids,
  ) async {
    final ids = bids.map((b) => b['transporter_id']).toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await supabase
        .from('profiles')
        .select('id, full_name, business_name, email')
        .inFilter('id', ids);
    return {
      for (final r in (rows as List))
        r['id'] as String:
            (r['business_name'] ?? r['full_name'] ?? r['email'] ?? 'Unnamed')
                .toString(),
    };
  }

  List<RoutePoint> _routePointsFor(Map<String, dynamic> freight) {
    final stopDetails = _stopDetailsList(freight['stop_details']);
    final stopPoints =
        stopDetails
            .where((row) => row is Map && row['kind'] != 'destination')
            .map((row) {
              final data = row as Map;
              return RoutePoint(
                label: (data['name'] ?? '').toString(),
                kind: RoutePointKind.stop,
                meta: _quantityMeta(data['cases'], data['weight_kg']),
              );
            })
            .where((point) => point.label.trim().isNotEmpty)
            .toList();

    final fallbackStops =
        ((freight['stops'] as List?) ?? const [])
            .map(
              (stop) =>
                  RoutePoint(label: stop.toString(), kind: RoutePointKind.stop),
            )
            .toList();

    return [
      RoutePoint(
        label: (freight['origin'] ?? '').toString(),
        kind: RoutePointKind.origin,
      ),
      ...(stopPoints.isNotEmpty ? stopPoints : fallbackStops),
      RoutePoint(
        label: (freight['destination_town'] ?? '').toString(),
        kind: RoutePointKind.destination,
        meta: _destinationMeta(freight),
      ),
    ];
  }

  String? _destinationMeta(Map<String, dynamic> freight) {
    final stopDetails = _stopDetailsList(freight['stop_details']);
    for (final row in stopDetails) {
      if (row is Map && row['kind'] == 'destination') {
        return _quantityMeta(row['cases'], row['weight_kg']);
      }
    }
    return null;
  }

  String? _quantityMeta(dynamic cases, dynamic weight) {
    final caseText = (cases ?? '').toString();
    final weightText = (weight ?? '').toString();
    final parts = [
      if (caseText.isNotEmpty && caseText != 'null') '$caseText Cases',
      if (weightText.isNotEmpty && weightText != 'null') '$weightText MT',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _bidderRow(
    String id,
    String label,
    double amount, {
    required bool disabled,
  }) {
    final selected = _selectedTransporterId == id;
    return InkWell(
      onTap:
          disabled
              ? null
              : () => setState(() {
                _selectedTransporterId = id;
                _selectedLabel = label;
              }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.accent : const Color(0xFFCAC4D0),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.accent : const Color(0xFF49454F),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

List<dynamic> _stopDetailsList(dynamic value) {
  return value is List ? value : const [];
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1DAE8)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6750A4)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D1B20),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwardPanel extends StatelessWidget {
  const _AwardPanel({
    required this.selectedLabel,
    required this.awarding,
    required this.onConfirm,
  });

  final String? selectedLabel;
  final bool awarding;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEADDFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OperationalStep(
            '2',
            operationalCopy(
              context,
              'Confirm assignment',
              'सौंपने की पुष्टि करें',
            ),
            operationalCopy(
              context,
              'This transporter will arrange the truck and delivery updates.',
              'यह ट्रांसपोर्टर ट्रक और डिलीवरी अपडेट की व्यवस्था करेगा।',
            ),
          ),
          Text(
            'Award to ${selectedLabel ?? "this transporter"}?',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.opsTransporterFillDetails,
            style: TextStyle(fontSize: 16, color: Color(0xFF49454F)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: PrimaryButton(
              label: awarding ? 'Awarding...' : 'Confirm winner',
              onPressed: awarding ? null : onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}
