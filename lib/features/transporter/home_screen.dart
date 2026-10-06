import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/bid_window.dart';
import '../../core/widgets/bid_date_label.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'widgets/transporter_workspace.dart';
import '../../l10n/app_localizations.dart';

/// Body-only version used inside [TransporterShell].
class TransporterHomeBody extends StatefulWidget {
  const TransporterHomeBody({
    super.key,
    this.openFreightsStream,
    this.wonFreightsFuture,
    this.displayName,
  });
  final Stream<List<Map<String, dynamic>>>? openFreightsStream;
  final Future<List<Map<String, dynamic>>>? wonFreightsFuture;
  final String? displayName;

  @override
  State<TransporterHomeBody> createState() => _TransporterHomeBodyState();
}

class _TransporterHomeBodyState extends State<TransporterHomeBody> {
  String _displayName = '';
  late final Stream<List<Map<String, dynamic>>> _openFreightsStream;
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _openFreightsStream =
        widget.openFreightsStream ?? FreightsRepo.instance.streamOpenFreights();
    _clock = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
    _loadName();
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _loadName() async {
    if (widget.displayName != null) {
      setState(() => _displayName = widget.displayName!);
      return;
    }
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    try {
      final row =
          await supabase
              .from('profiles')
              .select('full_name, business_name, email')
              .eq('id', uid)
              .maybeSingle();
      if (!mounted || row == null) return;
      final name =
          (row['full_name'] ??
                  row['business_name'] ??
                  (row['email'] as String?)?.split('@').first ??
                  '')
              .toString();
      setState(() => _displayName = name);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _loadName,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          WorkspaceHeader(
            title:
                _displayName.isEmpty
                    ? l.tpWelcome
                    : l.tpWelcomeName(_displayName),
            description: tpText(
              context,
              'Choose your next job or continue a trip. Keep your vehicle and driver details ready before dispatch.',
              'अगला काम चुनें या चल रही यात्रा जारी रखें। रवाना होने से पहले वाहन और ड्राइवर की जानकारी तैयार रखें।',
            ),
            icon: Icons.local_shipping_outlined,
            eyebrow: l.transporter,
            action: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed: () => context.go('/bids'),
              icon: const Icon(Icons.search),
              label: Text(l.tpLatestBids),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeading(
            title: tpText(
              context,
              'Continue your trips',
              'अपनी यात्रा जारी रखें',
            ),
            description: tpText(
              context,
              'Awarded work and delivery updates in one place.',
              'मिली हुई यात्राएँ और डिलीवरी अपडेट एक जगह।',
            ),
            action: TextButton(
              onPressed: () => context.go('/fleet'),
              child: Text(tpText(context, 'All trips', 'सभी यात्राएँ')),
            ),
          ),
          const SizedBox(height: 12),
          _WonBidsStrip(future: widget.wonFreightsFuture),
          const SizedBox(height: 24),
          SectionHeading(
            title: l.tpLatestBids,
            description: tpText(
              context,
              'Read the route and load, then quote your freight.',
              'मार्ग और माल का विवरण पढ़कर अपना भाड़ा दें।',
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _openFreightsStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return WorkspaceEmptyState(
                  title: tpText(
                    context,
                    'Open bids could not be loaded',
                    'खुली बोलियाँ लोड नहीं हुईं',
                  ),
                  message: tpText(
                    context,
                    'Check your connection and open the bids page to try again.',
                    'इंटरनेट जाँचकर बोलियों का पृष्ठ फिर खोलें।',
                  ),
                  icon: Icons.wifi_off,
                  action: OutlinedButton(
                    onPressed: () => context.go('/bids'),
                    child: Text(l.tpOpenBids),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final freights =
                  snap.data!
                      .where(
                        (f) =>
                            bidWindowPhase(
                              status: (f['status'] ?? '').toString(),
                              opensAt: bidTimestamp(f['bid_opens_at']),
                              closesAt: bidTimestamp(f['bid_closes_at']),
                            ) ==
                            BidWindowPhase.live,
                      )
                      .take(4)
                      .toList();
              if (freights.isEmpty) {
                return WorkspaceEmptyState(
                  title: l.tpNoOpenBidsSoon,
                  message: tpText(
                    context,
                    'You can prepare vehicles and drivers while waiting for new work.',
                    'नया काम आने तक वाहन और ड्राइवर की जानकारी तैयार कर सकते हैं।',
                  ),
                  icon: Icons.gavel_outlined,
                );
              }
              return TransporterCardGrid(
                children: [
                  for (final f in freights)
                    _BidTile(
                      route: freightView(f)['route'] as String,
                      summary: l.tpCasesWeight(
                        '${f['cases'] ?? 0}',
                        '${f['weight_kg'] ?? 0}',
                      ),
                      minsLeft: freightView(f)['minsLeft'] as int,
                      date: freightView(f)['created'] as DateTime?,
                      onTap: () => context.push('/bid/${f['id']}'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SectionHeading(
            title: l.tpQuickOptions,
            description: tpText(
              context,
              'Prepare your team before the next trip.',
              'अगली यात्रा से पहले अपनी टीम तैयार रखें।',
            ),
          ),
          const SizedBox(height: 12),
          TransporterCardGrid(
            children: [
              TransporterTaskCard(
                title: l.tpVehicles,
                description: l.tpAddOrDelete,
                actionLabel: tpText(context, 'Manage vehicles', 'वाहन सँभालें'),
                icon: Icons.local_shipping_outlined,
                onTap: () => context.push('/vehicles'),
              ),
              TransporterTaskCard(
                title: l.tpDrivers,
                description: tpText(
                  context,
                  'Save names, phone numbers and licence details.',
                  'नाम, फोन नंबर और लाइसेंस की जानकारी रखें।',
                ),
                actionLabel: tpText(
                  context,
                  'Manage drivers',
                  'ड्राइवर सँभालें',
                ),
                icon: Icons.badge_outlined,
                onTap: () => context.push('/drivers'),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _WonBidsStrip extends StatelessWidget {
  const _WonBidsStrip({this.future});
  final Future<List<Map<String, dynamic>>>? future;

  @override
  Widget build(BuildContext context) {
    final uid = future == null ? AuthService.instance.user?.id : null;
    if (uid == null && future == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future:
          future ??
          supabase
              .from('freights')
              .select(
                'id, origin, destination_town, status, vehicle_number, driver_name',
              )
              .eq('winner_profile_id', uid!)
              .order('dispatched_at', ascending: false)
              .limit(6)
              .then((rows) => (rows as List).cast<Map<String, dynamic>>()),
      builder: (context, snap) {
        if (snap.hasError) {
          return WorkspaceEmptyState(
            title: tpText(
              context,
              'Trips could not be loaded',
              'यात्राएँ लोड नहीं हुईं',
            ),
            message: tpText(
              context,
              'Open My trips to try again.',
              'फिर प्रयास करने के लिए अपनी यात्राएँ खोलें।',
            ),
            icon: Icons.wifi_off,
            action: OutlinedButton(
              onPressed: () => context.go('/fleet'),
              child: Text(tpText(context, 'My trips', 'मेरी यात्राएँ')),
            ),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 116,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return WorkspaceEmptyState(
            title: AppLocalizations.of(context)!.tpWonBidsEmpty,
            message: tpText(
              context,
              'Your confirmed work appears here after the office awards a trip.',
              'कार्यालय के यात्रा देने पर आपका पक्का काम यहाँ दिखेगा।',
            ),
            icon: Icons.route_outlined,
          );
        }
        return TransporterCardGrid(
          children: [
            for (final row in rows.take(4))
              TransporterTaskCard(
                title: '${row['origin']} → ${row['destination_town']}',
                description:
                    (row['vehicle_number'] ?? '').toString().isEmpty
                        ? tpText(
                          context,
                          'Vehicle and driver need to be confirmed before dispatch.',
                          'रवाना होने से पहले वाहन और ड्राइवर तय करें।',
                        )
                        : '${tpText(context, 'Vehicle', 'वाहन')}: ${row['vehicle_number']}',
                actionLabel: tpText(
                  context,
                  row['status'] == 'completed'
                      ? 'View delivery record'
                      : 'Open trip & next step',
                  row['status'] == 'completed'
                      ? 'डिलीवरी विवरण देखें'
                      : 'यात्रा और अगला काम देखें',
                ),
                icon: Icons.route_outlined,
                onTap: () => context.push('/bid/${row['id']}/after'),
              ),
          ],
        );
      },
    );
  }
}

class _BidTile extends StatelessWidget {
  const _BidTile({
    required this.route,
    required this.summary,
    required this.minsLeft,
    required this.date,
    required this.onTap,
  });
  final String route;
  final String summary;
  final int minsLeft;
  final DateTime? date;
  final VoidCallback onTap;

  String _label(AppLocalizations l) {
    if (minsLeft <= 0) return l.tpClosed;
    if (minsLeft >= 60) {
      return l.tpTimeHoursLeft(minsLeft ~/ 60, minsLeft % 60);
    }
    return l.tpTimeMinutesLeft(minsLeft);
  }

  @override
  Widget build(BuildContext context) {
    final urgent = minsLeft > 0 && minsLeft < 30;
    return TransporterTaskCard(
      title: route,
      description: summary,
      actionLabel: tpText(
        context,
        'View load & quote freight',
        'माल देखें और भाड़ा दें',
      ),
      icon: Icons.inventory_2_outlined,
      onTap: onTap,
      status: StatusBadge(
        label: _label(AppLocalizations.of(context)!),
        tone: urgent ? WorkspaceTone.warning : WorkspaceTone.info,
      ),
      details: BidDateLabel(date: date),
    );
  }
}
