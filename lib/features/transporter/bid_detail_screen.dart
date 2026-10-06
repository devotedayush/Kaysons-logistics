import '../../core/widgets/workspace_widgets.dart';
import 'widgets/transporter_workspace.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/utils/bid_window.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/route_timeline.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/transporter_bottom_nav.dart';

class BidDetailScreen extends StatefulWidget {
  const BidDetailScreen({
    super.key,
    required this.bidId,
    this.freightStream,
    this.bidsStream,
  });

  final String bidId;
  final Stream<Map<String, dynamic>?>? freightStream;
  final Stream<List<Map<String, dynamic>>>? bidsStream;

  @override
  State<BidDetailScreen> createState() => _BidDetailScreenState();
}

class _BidDetailScreenState extends State<BidDetailScreen> {
  final _bidController = TextEditingController();
  late Stream<Map<String, dynamic>?> _freightStream;
  late Stream<List<Map<String, dynamic>>> _bidsStream;
  bool _placing = false;
  String? _bidError;
  final _quoteKey = GlobalKey();
  bool _hasExistingBid = false;
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _freightStream =
        widget.freightStream ??
        FreightsRepo.instance.streamFreight(widget.bidId);
    _bidsStream =
        widget.bidsStream ?? FreightsRepo.instance.streamBidsFor(widget.bidId);
    _clock = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
    _prefillMyBid();
  }

  @override
  void didUpdateWidget(covariant BidDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bidId != widget.bidId) {
      _bidController.clear();
      _hasExistingBid = false;
      _freightStream =
          widget.freightStream ??
          FreightsRepo.instance.streamFreight(widget.bidId);
      _bidsStream =
          widget.bidsStream ??
          FreightsRepo.instance.streamBidsFor(widget.bidId);
      _prefillMyBid();
    } else if (oldWidget.freightStream != widget.freightStream ||
        oldWidget.bidsStream != widget.bidsStream) {
      _freightStream =
          widget.freightStream ??
          FreightsRepo.instance.streamFreight(widget.bidId);
      _bidsStream =
          widget.bidsStream ??
          FreightsRepo.instance.streamBidsFor(widget.bidId);
    }
  }

  Future<void> _prefillMyBid() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    final bidId = widget.bidId;
    final mine = await FreightsRepo.instance.getMyBid(bidId, uid);
    if (!mounted || widget.bidId != bidId) return;
    if (mine != null && mine['amount'] != null) {
      _bidController.text = (mine['amount'] as num).toStringAsFixed(0);
    }
    setState(() => _hasExistingBid = mine != null);
  }

  @override
  void dispose() {
    _clock.cancel();
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _submitBid() async {
    if (_placing) return;
    final value = double.tryParse(
      _bidController.text.replaceAll(',', '').trim(),
    );
    if (value == null || !value.isFinite || value <= 0) {
      setState(
        () =>
            _bidError = tpText(
              context,
              'Enter a freight amount greater than zero.',
              'शून्य से अधिक भाड़ा भरें।',
            ),
      );
      return;
    }
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    setState(() => _placing = true);
    try {
      final freight = await FreightsRepo.instance.fetchFreight(widget.bidId);
      if (freight == null ||
          bidWindowPhase(
                status: (freight['status'] ?? '').toString(),
                opensAt: bidTimestamp(freight['bid_opens_at']),
                closesAt: bidTimestamp(freight['bid_closes_at']),
              ) !=
              BidWindowPhase.live) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bidding is not open yet.')),
        );
        return;
      }
      await FreightsRepo.instance.upsertBid(
        freightId: widget.bidId,
        transporterId: uid,
        amount: value,
      );
      if (!mounted) return;
      setState(() => _hasExistingBid = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tpBidPlaced(value.toStringAsFixed(0)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tpBidFailed('$e')),
        ),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _freightStream,
          builder: (context, snap) {
            final freight = snap.data;
            final route =
                freight == null
                    ? '...'
                    : '${freight['origin']} → ${freight['destination_town']}';
            final status = freight?['status'] as String? ?? '';
            final myUid = AuthService.instance.user?.id;
            final winnerId = freight?['winner_profile_id'] as String?;
            final iWon = winnerId != null && winnerId == myUid;
            final opensAt = bidTimestamp(freight?['bid_opens_at']);
            final closesAt = bidTimestamp(freight?['bid_closes_at']);
            final phase = bidWindowPhase(
              status: status,
              opensAt: opensAt,
              closesAt: closesAt,
            );
            final bidOpen = phase == BidWindowPhase.live;
            final hiddenClosedLoss =
                freight != null && !iWon && phase == BidWindowPhase.closed;

            if (hiddenClosedLoss) {
              return _ResponsiveTransporterPage(
                isWide: isWide,
                currentIndex: 1,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: Color(0xFF49454F),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l.tpBidClosed,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D1B20),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l.tpBidClosedHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            color: Color(0xFF49454F),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => context.go('/bids'),
                          child: Text(l.tpBackToOpenBids),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snap.hasError) {
              return WorkspaceEmptyState(
                title: tpText(
                  context,
                  'This load could not be opened',
                  'माल का विवरण नहीं खुला',
                ),
                message: tpText(
                  context,
                  'Check your connection and return to open bids.',
                  'इंटरनेट जाँचकर खुली बोलियों पर लौटें।',
                ),
                icon: Icons.wifi_off,
                action: FilledButton(
                  onPressed: () => context.go('/bids'),
                  child: Text(l.tpBackToOpenBids),
                ),
              );
            }
            if (freight == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _ResponsiveTransporterPage(
              isWide: isWide,
              currentIndex: 1,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l.tpBackToOpenBids),
                    ),
                  ),
                  WorkspaceHeader(
                    action:
                        bidOpen
                            ? FilledButton.icon(
                              onPressed: () {
                                final target = _quoteKey.currentContext;
                                if (target != null) {
                                  Scrollable.ensureVisible(
                                    target,
                                    duration: const Duration(milliseconds: 300),
                                    alignment: .1,
                                  );
                                }
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(
                                tpText(context, 'Quote freight', 'भाड़ा दें'),
                              ),
                            )
                            : null,
                    title: route,
                    description: tpText(
                      context,
                      'Review this load before quoting. Your amount is the total freight for the complete route.',
                      'भाड़ा देने से पहले माल का विवरण देखें। आपकी राशि पूरे मार्ग का कुल भाड़ा है।',
                    ),
                    icon: Icons.inventory_2_outlined,
                    eyebrow: tpText(context, 'Load details', 'माल का विवरण'),
                    summary: _StatusBanner(
                      status: status,
                      opensAt: opensAt,
                      closesAt: closesAt,
                      iWon: iWon,
                      onOpenDelivery:
                          iWon
                              ? () => context.push('/bid/${widget.bidId}/after')
                              : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  WorkspaceFormLayout(
                    showAsideOnMobile: true,
                    aside: WorkspaceSection(
                      title: tpText(context, 'Route & load', 'मार्ग और माल'),
                      description: tpText(
                        context,
                        'Pickup, stops and quantities for this trip.',
                        'इस यात्रा के माल उठाने का स्थान, पड़ाव और मात्रा।',
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusBadge(
                              label:
                                  '${freight['cases'] ?? '—'} ${tpText(context, 'cases', 'केस')}',
                            ),
                            StatusBadge(
                              label: '${freight['weight_kg'] ?? '—'} MT',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        RouteTimeline(
                          points: _routePointsFor(context, freight),
                        ),
                        const SizedBox(height: 16),
                        GuidanceCard(
                          title: tpText(
                            context,
                            'Before you quote',
                            'भाड़ा देने से पहले',
                          ),
                          message: tpText(
                            context,
                            'Check that your vehicle can carry this load and serve every stop. The office will confirm the winning quote.',
                            'जाँचें कि आपका वाहन यह माल ले जा सकता है और हर पड़ाव पहुँच सकता है। कार्यालय चुने गए भाड़े की पुष्टि करेगा।',
                          ),
                        ),
                      ],
                    ),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (bidOpen)
                          WorkspaceSection(
                            key: _quoteKey,
                            title: tpText(
                              context,
                              _hasExistingBid
                                  ? 'Update your freight quote'
                                  : 'Your freight quote',
                              _hasExistingBid
                                  ? 'अपना भाड़ा बदलें'
                                  : 'अपना भाड़ा दें',
                            ),
                            description: tpText(
                              context,
                              'Enter the total amount in rupees.',
                              'कुल राशि रुपये में भरें।',
                            ),
                            children: [
                              TextField(
                                controller: _bidController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  if (_bidError != null) {
                                    setState(() => _bidError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: tpText(
                                    context,
                                    'Total freight (₹)',
                                    'कुल भाड़ा (₹)',
                                  ),
                                  prefixText: '₹ ',
                                  hintText: '15000',
                                  errorText: _bidError,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.all(18),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: PrimaryButton(
                                  label:
                                      _placing
                                          ? l.tpPlacing
                                          : (_hasExistingBid
                                              ? l.tpUpdateBid
                                              : l.tpPlaceBid),
                                  onPressed: _placing ? null : _submitBid,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tpText(
                                  context,
                                  'You can change your quote while bidding is open.',
                                  'बोली खुली रहने तक अपना भाड़ा बदल सकते हैं।',
                                ),
                                style: const TextStyle(height: 1.5),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        _biddingSummary(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _biddingSummary() => StreamBuilder<List<Map<String, dynamic>>>(
    stream: _bidsStream,
    builder: (context, snap) {
      final l = AppLocalizations.of(context)!;
      final bids = snap.data ?? const [];
      return WorkspaceSection(
        title: tpText(context, 'Current quotes', 'वर्तमान भाड़े'),
        children: [
          if (snap.hasError)
            Text(
              tpText(
                context,
                'Quotes could not be loaded. Your saved quote is not changed.',
                'भाड़े लोड नहीं हुए। आपका सहेजा हुआ भाड़ा नहीं बदला।',
              ),
            )
          else ...[
            Text(
              bids.isEmpty
                  ? l.tpNoBidsYet
                  : '₹ ${(bids.first['amount'] as num).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            Text(
              l.tpAnonymousBidders(bids.length),
              style: const TextStyle(height: 1.5),
            ),
            if (bids.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    tpText(context, 'Compare quotes', 'भाड़ों की तुलना करें'),
                  ),
                  children: [
                    for (final (i, bid) in bids.indexed)
                      _bidRow(
                        index: i + 1,
                        amount: (bid['amount'] as num).toDouble(),
                        isMine:
                            bid['transporter_id'] ==
                            AuthService.instance.user?.id,
                      ),
                  ],
                ),
              ),
          ],
        ],
      );
    },
  );

  Widget _bidRow({
    required int index,
    required double amount,
    required bool isMine,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFFF6EDFB) : Colors.white,
        border: Border.all(color: const Color(0xFFCAC4D0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFECE6F0),
            child: Text(
              '#$index',
              style: const TextStyle(fontSize: 13, color: Color(0xFF1D1B20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMine
                  ? AppLocalizations.of(context)!.tpYou
                  : AppLocalizations.of(context)!.tpAnonymousBidder,
              style: const TextStyle(fontSize: 18, color: Color(0xFF1D1B20)),
            ),
          ),
          Text(
            '₹ ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D1B20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveTransporterPage extends StatelessWidget {
  const _ResponsiveTransporterPage({
    required this.isWide,
    required this.currentIndex,
    required this.child,
  });

  final bool isWide;
  final int currentIndex;
  final Widget child;

  void _goto(BuildContext context, int index) {
    if (index == 0) context.go('/home');
    if (index == 1) context.go('/bids');
    if (index == 2) context.go('/fleet');
  }

  @override
  Widget build(BuildContext context) {
    if (isWide) return child;

    return Column(
      children: [
        Expanded(child: child),
        TransporterBottomNav(
          currentIndex: currentIndex,
          onTap: (index) => _goto(context, index),
          onProfile: () => context.push('/profile'),
          onLogout: () async {
            await AuthService.instance.signOut();
            if (context.mounted) context.go('/welcome');
          },
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.status,
    required this.opensAt,
    required this.closesAt,
    required this.iWon,
    required this.onOpenDelivery,
  });
  final String status;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final bool iWon;
  final VoidCallback? onOpenDelivery;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String label;
    Color bg;
    Color fg;
    IconData icon;
    switch (status) {
      case 'bidding':
        final phase = bidWindowPhase(
          status: status,
          opensAt: opensAt,
          closesAt: closesAt,
        );
        final minutes = closesAt?.difference(DateTime.now()).inMinutes ?? 0;
        label =
            phase == BidWindowPhase.live
                ? (closesAt == null
                    ? l.tpBiddingOpen
                    : minutes >= 60
                    ? l.tpBiddingOpenHours(minutes ~/ 60, minutes % 60)
                    : l.tpBiddingOpenMinutes(minutes.clamp(0, 59)))
                : phase == BidWindowPhase.upcoming
                ? tpText(
                  context,
                  'Bidding opens soon. You can review the load now.',
                  'बोली जल्द खुलेगी। अभी माल का विवरण देख सकते हैं।',
                )
                : l.tpClosed;
        bg = const Color(0xFFF6EDFB);
        fg = const Color(0xFF4F378A);
        icon = Icons.gavel_outlined;
        break;
      case 'awarded':
      case 'dispatched':
        label = iWon ? l.tpYouWonBid : l.tpAwardedOther;
        bg = iWon ? const Color(0xFFE7F6EC) : const Color(0xFFECE6F0);
        fg = iWon ? const Color(0xFF14A33A) : const Color(0xFF49454F);
        icon = iWon ? Icons.emoji_events : Icons.block;
        break;
      case 'locked':
      case 'completed':
        label = iWon ? l.tpDeliveryStatus(status) : l.tpClosed;
        bg = const Color(0xFFECE6F0);
        fg = const Color(0xFF49454F);
        icon = Icons.lock_outline;
        break;
      default:
        label = status.toUpperCase();
        bg = const Color(0xFFECE6F0);
        fg = const Color(0xFF49454F);
        icon = Icons.info_outline;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          if (onOpenDelivery != null)
            TextButton(onPressed: onOpenDelivery, child: Text(l.tpTrackArrow)),
        ],
      ),
    );
  }
}

List<RoutePoint> _routePointsFor(
  BuildContext context,
  Map<String, dynamic> freight,
) {
  final stopDetails = _stopDetailsList(freight['stop_details']);
  final stopPoints =
      stopDetails
          .where((row) => row is Map && row['kind'] != 'destination')
          .map((row) {
            final data = row as Map;
            return RoutePoint(
              label: (data['name'] ?? '').toString(),
              kind: RoutePointKind.stop,
              meta: _quantityMeta(context, data['cases'], data['weight_kg']),
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
      meta: _destinationMeta(context, freight),
    ),
  ];
}

String? _destinationMeta(BuildContext context, Map<String, dynamic> freight) {
  final stopDetails = _stopDetailsList(freight['stop_details']);
  for (final row in stopDetails) {
    if (row is Map && row['kind'] == 'destination') {
      return _quantityMeta(context, row['cases'], row['weight_kg']);
    }
  }
  return null;
}

List<dynamic> _stopDetailsList(dynamic value) {
  return value is List ? value : const [];
}

String? _quantityMeta(BuildContext context, dynamic cases, dynamic weight) {
  final caseText = (cases ?? '').toString();
  final weightText = (weight ?? '').toString();
  final parts = [
    if (caseText.isNotEmpty && caseText != 'null')
      AppLocalizations.of(context)!.tpCases(caseText),
    if (weightText.isNotEmpty && weightText != 'null') '$weightText MT',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
