import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/route_timeline.dart';
import 'widgets/transporter_bottom_nav.dart';

class BidDetailScreen extends StatefulWidget {
  const BidDetailScreen({super.key, required this.bidId});

  final String bidId;

  @override
  State<BidDetailScreen> createState() => _BidDetailScreenState();
}

class _BidDetailScreenState extends State<BidDetailScreen> {
  final _bidController = TextEditingController();
  bool _placing = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _prefillMyBid();
  }

  Future<void> _prefillMyBid() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    final mine = await FreightsRepo.instance.getMyBid(widget.bidId, uid);
    if (!mounted) return;
    if (mine != null && mine['amount'] != null) {
      _bidController.text = (mine['amount'] as num).toStringAsFixed(0);
    }
    _prefilled = true;
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _submitBid() async {
    if (_placing) return;
    final value = double.tryParse(
      _bidController.text.replaceAll(',', '').trim(),
    );
    if (value == null || value <= 0) return;
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    setState(() => _placing = true);
    try {
      await FreightsRepo.instance.upsertBid(
        freightId: widget.bidId,
        transporterId: uid,
        amount: value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bid placed: ₹${value.toStringAsFixed(0)}. You can revise it until bidding closes.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bid failed: $e')));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: FreightsRepo.instance.streamFreight(widget.bidId),
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
            final closesAt = DateTime.tryParse(
              (freight?['bid_closes_at'] ?? '').toString(),
            );
            final minsLeft = closesAt?.difference(DateTime.now()).inMinutes;
            final openByTime =
                closesAt != null && closesAt.isAfter(DateTime.now());
            final bidOpen = status == 'bidding' && openByTime;
            final hiddenClosedLoss =
                freight != null &&
                !iWon &&
                (status != 'bidding' || !openByTime);

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
                        const Text(
                          'Bid closed',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D1B20),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Only bids you win stay available in your past bids and fleet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: Color(0xFF49454F),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => context.go('/bids'),
                          child: const Text('Back to open bids'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return _ResponsiveTransporterPage(
              isWide: isWide,
              currentIndex: 1,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _HeaderHero(route: route),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _StatusBanner(
                      status: status,
                      minsLeft: minsLeft,
                      iWon: iWon,
                      onOpenDelivery:
                          iWon
                              ? () => context.push('/bid/${widget.bidId}/after')
                              : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (freight != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: RouteTimeline(points: _routePointsFor(freight)),
                    ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Live Bidding',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1B20),
                      ),
                    ),
                  ),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FreightsRepo.instance.streamBidsFor(widget.bidId),
                    builder: (context, snap) {
                      final bids = snap.data ?? const [];
                      final lowest =
                          bids.isNotEmpty
                              ? (bids.first['amount'] as num).toDouble()
                              : null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              lowest == null
                                  ? 'No bids yet'
                                  : '₹ ${lowest.toStringAsFixed(0)}/-',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D1B20),
                              ),
                            ),
                            Text(
                              '${bids.length} anonymous bidder(s)',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF49454F),
                              ),
                            ),
                            const SizedBox(height: 18),
                            ...bids.asMap().entries.map(
                              (e) => _bidRow(
                                index: e.key + 1,
                                amount: (e.value['amount'] as num).toDouble(),
                                isMine:
                                    e.value['transporter_id'] ==
                                    AuthService.instance.user?.id,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (bidOpen)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _bidController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 20),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: '15000',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 18,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCAC4D0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                    color: AppColors.black,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 170,
                            height: 58,
                            child: PrimaryButton(
                              label:
                                  _placing
                                      ? 'Placing...'
                                      : (_prefilled &&
                                              _bidController.text.isNotEmpty
                                          ? 'Update bid'
                                          : 'Place bid'),
                              onPressed: _placing ? null : _submitBid,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

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
              isMine ? 'You' : 'Anonymous bidder',
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
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesktopTransporterNav(
            currentIndex: currentIndex,
            onTap: (index) => _goto(context, index),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: child,
              ),
            ),
          ),
        ],
      );
    }

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

class _DesktopTransporterNav extends StatelessWidget {
  const _DesktopTransporterNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      margin: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9E1F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_shipping_outlined, size: 30),
          const SizedBox(height: 20),
          const Text(
            'Transporter',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage bids, fleet, and delivery updates from the browser.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF6B6176),
            ),
          ),
          const SizedBox(height: 28),
          _DesktopNavTile(
            selected: currentIndex == 0,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            onTap: () => onTap(0),
          ),
          const SizedBox(height: 8),
          _DesktopNavTile(
            selected: currentIndex == 1,
            icon: Icons.gavel_outlined,
            label: 'Bids',
            onTap: () => onTap(1),
          ),
          const SizedBox(height: 8),
          _DesktopNavTile(
            selected: currentIndex == 2,
            icon: Icons.local_shipping_outlined,
            label: 'Fleet',
            onTap: () => onTap(2),
          ),
          const Spacer(),
          _DesktopNavTile(
            selected: false,
            icon: Icons.account_circle_outlined,
            label: 'Profile',
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 8),
          _DesktopNavTile(
            selected: false,
            icon: Icons.logout,
            label: 'Logout',
            onTap: () async {
              await AuthService.instance.signOut();
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
    );
  }
}

class _DesktopNavTile extends StatelessWidget {
  const _DesktopNavTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6EDFB) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFE1D2F8) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF49454F)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected
                          ? const Color(0xFF1D1B20)
                          : const Color(0xFF49454F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.status,
    required this.minsLeft,
    required this.iWon,
    required this.onOpenDelivery,
  });
  final String status;
  final int? minsLeft;
  final bool iWon;
  final VoidCallback? onOpenDelivery;

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;
    IconData icon;
    switch (status) {
      case 'bidding':
        if (minsLeft != null && minsLeft! > 0) {
          label =
              minsLeft! >= 60
                  ? 'Bidding open · ${minsLeft! ~/ 60}h ${minsLeft! % 60}m left'
                  : 'Bidding open · ${minsLeft}m left';
        } else {
          label = 'Bidding open';
        }
        bg = const Color(0xFFF6EDFB);
        fg = const Color(0xFF4F378A);
        icon = Icons.gavel_outlined;
        break;
      case 'awarded':
      case 'dispatched':
        label = iWon ? 'You won this bid' : 'Awarded to another transporter';
        bg = iWon ? const Color(0xFFE7F6EC) : const Color(0xFFECE6F0);
        fg = iWon ? const Color(0xFF14A33A) : const Color(0xFF49454F);
        icon = iWon ? Icons.emoji_events : Icons.block;
        break;
      case 'locked':
      case 'completed':
        label = iWon ? 'Delivery $status' : 'Closed';
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
            TextButton(onPressed: onOpenDelivery, child: const Text('Track →')),
        ],
      ),
    );
  }
}

class _HeaderHero extends StatelessWidget {
  const _HeaderHero({required this.route});
  final String route;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 220,
          color: const Color(0xFFECE6F0),
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
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
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

List<dynamic> _stopDetailsList(dynamic value) {
  return value is List ? value : const [];
}

String? _quantityMeta(dynamic cases, dynamic weight) {
  final caseText = (cases ?? '').toString();
  final weightText = (weight ?? '').toString();
  final parts = [
    if (caseText.isNotEmpty && caseText != 'null') '$caseText Cases',
    if (weightText.isNotEmpty && weightText != 'null') '$weightText Ton',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
