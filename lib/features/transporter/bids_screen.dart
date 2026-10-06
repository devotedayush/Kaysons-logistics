import '../../core/widgets/workspace_widgets.dart';
import 'widgets/transporter_workspace.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/utils/bid_window.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/widgets/bid_date_label.dart';
import '../../core/widgets/date_window_bar.dart';
import '../../l10n/app_localizations.dart';

class BidsBody extends StatefulWidget {
  const BidsBody({super.key, this.openFreightsStream, this.historyFuture});
  final Stream<List<Map<String, dynamic>>>? openFreightsStream;
  final Future<List<Map<String, dynamic>>>? historyFuture;

  @override
  State<BidsBody> createState() => _BidsBodyState();
}

class _BidsBodyState extends State<BidsBody> {
  late final Future<List<Map<String, dynamic>>> _historyFuture;
  late final Stream<List<Map<String, dynamic>>> _openFreightsStream;
  late final Timer _clock;
  String _query = '';
  bool _showHistory = false;
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _openFreightsStream =
        widget.openFreightsStream ?? FreightsRepo.instance.streamOpenFreights();
    _clock = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
    final uid =
        widget.historyFuture == null ? AuthService.instance.user?.id : null;
    _historyFuture =
        widget.historyFuture ??
        (uid == null
            ? Future.value(const <Map<String, dynamic>>[])
            : FreightsRepo.instance.fetchMyBidHistory(uid));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 7)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customStart = picked;
      _customEnd ??= picked;
    });
  }

  Future<void> _pickEnd() async {
    final base = _customEnd ?? _customStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: base,
    );
    if (picked == null || !mounted) return;
    setState(() => _customEnd = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    bool matches(Map<String, dynamic> row) =>
        '${row['origin']} ${row['destination_town']} ${row['cases']}'
            .toLowerCase()
            .contains(_query.toLowerCase()) &&
        withinDateWindow(
          DateTime.tryParse((row['created_at'] ?? '').toString()),
          rangeDays: _rangeDays,
          customStart: _customStart,
          customEnd: _customEnd,
        );
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _openFreightsStream,
      builder: (context, snap) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _historyFuture,
          builder: (context, historySnap) {
            final live =
                (snap.data ?? []).where(_isOpen).where(matches).toList();
            final past =
                (historySnap.data ?? [])
                    .where((r) => !_isOpen(r))
                    .where(matches)
                    .toList();
            final rows = _showHistory ? past : live;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                WorkspaceHeader(
                  title: l.tpOpenBids,
                  description: tpText(
                    context,
                    'Find a suitable load, check the route and quote the total freight. A quote is only confirmed when the office awards the trip.',
                    'सही माल चुनें, मार्ग जाँचें और कुल भाड़ा दें। कार्यालय के यात्रा देने पर ही काम पक्का होता है।',
                  ),
                  icon: Icons.gavel_outlined,
                  summary: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusBadge(
                        label: l.tpOpenBidsCount(live.length),
                        tone: WorkspaceTone.info,
                      ),
                      StatusBadge(label: l.tpBidHistoryCount(past.length)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TransporterSearch(
                  label: tpText(
                    context,
                    'Search origin or destination',
                    'माल उठाने या पहुँचाने का शहर खोजें',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(tpText(context, 'Open now', 'अभी खुली')),
                      selected: !_showHistory,
                      onSelected: (_) => setState(() => _showHistory = false),
                    ),
                    ChoiceChip(
                      label: Text(l.tpBidHistory),
                      selected: _showHistory,
                      onSelected: (_) => setState(() => _showHistory = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: ExpansionTile(
                    title: Text(
                      tpText(context, 'Filter by date', 'तारीख से छाँटें'),
                    ),
                    subtitle: Text(
                      tpText(
                        context,
                        'Currently showing the last $_rangeDays days',
                        'अभी पिछले $_rangeDays दिन दिख रहे हैं',
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: DateWindowBar(
                          rangeDays: _rangeDays,
                          customStart: _customStart,
                          customEnd: _customEnd,
                          onSelectRange:
                              (days) => setState(() {
                                _rangeDays = days;
                                _customStart = null;
                                _customEnd = null;
                              }),
                          onPickStart: _pickStart,
                          onPickEnd: _pickEnd,
                          onClearCustom:
                              () => setState(() {
                                _customStart = null;
                                _customEnd = null;
                              }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (snap.hasError || (_showHistory && historySnap.hasError))
                  WorkspaceEmptyState(
                    title: tpText(
                      context,
                      'Bids could not be loaded',
                      'बोलियाँ लोड नहीं हुईं',
                    ),
                    message: tpText(
                      context,
                      'Check your connection. Return to this page to reload the latest bids.',
                      'इंटरनेट जाँचें। नई बोलियाँ लोड करने के लिए यह पृष्ठ फिर खोलें।',
                    ),
                    icon: Icons.wifi_off,
                  )
                else if (!snap.hasData ||
                    (_showHistory && !historySnap.hasData))
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (rows.isEmpty)
                  WorkspaceEmptyState(
                    title:
                        _query.isNotEmpty
                            ? tpText(
                              context,
                              'No matching routes',
                              'कोई मिलता हुआ मार्ग नहीं',
                            )
                            : _showHistory
                            ? l.tpWonBidsEmpty
                            : l.tpNoOpenBids,
                    message: tpText(
                      context,
                      'Try another city or expand the date filter. New open bids appear here automatically.',
                      'दूसरा शहर खोजें या तारीख का दायरा बढ़ाएँ। नई खुली बोलियाँ अपने आप यहाँ दिखेंगी।',
                    ),
                    icon: Icons.search_off,
                  )
                else
                  TransporterCardGrid(
                    children: [
                      for (final row in rows) _tile(context, freightView(row)),
                    ],
                  ),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }

  bool _isOpen(Map<String, dynamic> row) {
    return bidWindowPhase(
          status: (row['status'] ?? '').toString(),
          opensAt: bidTimestamp(row['bid_opens_at']),
          closesAt: bidTimestamp(row['bid_closes_at']),
        ) ==
        BidWindowPhase.live;
  }

  Widget _tile(BuildContext context, Map<String, dynamic> v) {
    final minsLeft = v['minsLeft'] as int;
    final urgent = minsLeft > 0 && minsLeft < 30;
    final l = AppLocalizations.of(context)!;
    final statusLabel = _bidStatusLabel(l, v['status'] as String, minsLeft);
    final label =
        minsLeft <= 0
            ? l.tpClosed
            : minsLeft >= 60
            ? l.tpTimeHoursLeft(minsLeft ~/ 60, minsLeft % 60)
            : l.tpTimeMinutesLeft(minsLeft);

    return TransporterTaskCard(
      title: v['route'] as String,
      description: l.tpCasesWeight(
        '${v['cases']}',
        formatMetricTons(v['weight_kg']),
      ),
      icon: Icons.inventory_2_outlined,
      status: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusBadge(
            label: statusLabel,
            tone: minsLeft > 0 ? WorkspaceTone.info : WorkspaceTone.neutral,
          ),
          if (minsLeft > 0)
            StatusBadge(
              label: label,
              tone: urgent ? WorkspaceTone.warning : WorkspaceTone.neutral,
            ),
        ],
      ),
      details: BidDateLabel(date: v['created'] as DateTime?),
      actionLabel: tpText(
        context,
        minsLeft > 0 ? 'View load & quote freight' : 'View bid details',
        minsLeft > 0 ? 'माल देखें और भाड़ा दें' : 'बोली का विवरण देखें',
      ),
      onTap: () => context.push('/bid/${v['id']}'),
    );
  }

  String _bidStatusLabel(AppLocalizations l, String status, int minsLeft) {
    if (status == 'completed') return l.tpStatusCompleted;
    if (status == 'bidding' && minsLeft > 0) return l.tpStatusOpen;
    switch (status) {
      case 'bidding':
        return l.tpStatusExpired;
      case 'awarded':
        return l.tpStatusAwarded;
      case 'dispatched':
        return l.tpStatusDispatched;
      case 'locked':
        return l.tpStatusLocked;
      default:
        return l.tpStatusClosed;
    }
  }
}
