import '../../core/widgets/workspace_widgets.dart';
import 'widgets/transporter_workspace.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../l10n/app_localizations.dart';

class FleetBody extends StatefulWidget {
  const FleetBody({super.key, this.loadData});
  final Future<List<Map<String, dynamic>>> Function()? loadData;

  @override
  State<FleetBody> createState() => _FleetBodyState();
}

class _FleetBodyState extends State<FleetBody> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  bool _failed = false;
  String _query = '';
  bool _completedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.loadData != null) {
      setState(() {
        _loading = true;
        _failed = false;
      });
      try {
        final rows = await widget.loadData!();
        if (mounted) {
          setState(() {
            _entries = rows;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loading = false;
            _failed = true;
          });
        }
      }
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });
    final uid = AuthService.instance.user?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final rows = await supabase
          .from('freights')
          .select(
            'id, origin, destination_town, cases, weight_kg, status, vehicle_number, driver_name',
          )
          .eq('winner_profile_id', uid)
          .order('dispatched_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _entries = (rows as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final visible =
        _entries.where((row) {
          final done = row['status'] == 'completed';
          return (!_completedOnly || done) &&
              '${row['origin']} ${row['destination_town']} ${row['vehicle_number']} ${row['driver_name']}'
                  .toLowerCase()
                  .contains(_query.toLowerCase());
        }).toList();
    final active = _entries.where((e) => e['status'] != 'completed').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          WorkspaceHeader(
            title: tpText(context, 'My trips', 'मेरी यात्राएँ'),
            description: tpText(
              context,
              'Your awarded trips, from vehicle assignment to delivery. Open a trip to see the next step.',
              'वाहन तय करने से डिलीवरी तक आपकी यात्राएँ। अगला काम देखने के लिए यात्रा खोलें।',
            ),
            icon: Icons.route_outlined,
            summary: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(
                  label: tpText(
                    context,
                    '$active active trips',
                    '$active चालू यात्राएँ',
                  ),
                  tone: WorkspaceTone.info,
                ),
                StatusBadge(
                  label: tpText(
                    context,
                    '${_entries.length - active} finished trips',
                    '${_entries.length - active} पूरी यात्राएँ',
                  ),
                  tone: WorkspaceTone.success,
                ),
              ],
            ),
            action: OutlinedButton.icon(
              onPressed: () => context.push('/vehicles'),
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(l.tpManageVehicles),
            ),
          ),
          const SizedBox(height: 20),
          TransporterSearch(
            label: tpText(
              context,
              'Search route, vehicle or driver',
              'मार्ग, वाहन या ड्राइवर खोजें',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(tpText(context, 'All trips', 'सभी यात्राएँ')),
                selected: !_completedOnly,
                onSelected: (_) => setState(() => _completedOnly = false),
              ),
              ChoiceChip(
                label: Text(tpText(context, 'Finished trips', 'पूरी यात्राएँ')),
                selected: _completedOnly,
                onSelected: (_) => setState(() => _completedOnly = true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_failed)
            WorkspaceEmptyState(
              title: tpText(
                context,
                'Trips could not be loaded',
                'यात्राएँ लोड नहीं हुईं',
              ),
              message: tpText(
                context,
                'Check your connection and try again.',
                'इंटरनेट जाँचकर फिर प्रयास करें।',
              ),
              icon: Icons.wifi_off,
              action: FilledButton(
                onPressed: _load,
                child: Text(tpText(context, 'Try again', 'फिर प्रयास करें')),
              ),
            )
          else if (_entries.isEmpty)
            WorkspaceEmptyState(
              title: l.tpNoWonBids,
              message: tpText(
                context,
                'Find an open bid and quote your freight. Awarded trips will appear here.',
                'खुली बोली में अपना भाड़ा दें। मिली हुई यात्राएँ यहाँ दिखेंगी।',
              ),
              icon: Icons.route_outlined,
              action: FilledButton.icon(
                onPressed: () => context.go('/bids'),
                icon: const Icon(Icons.search),
                label: Text(l.tpOpenBids),
              ),
            )
          else if (visible.isEmpty)
            WorkspaceEmptyState(
              title: tpText(
                context,
                'No trips match this search',
                'इस खोज में कोई यात्रा नहीं',
              ),
              message: tpText(
                context,
                'Change the search or choose All trips.',
                'खोज बदलें या सभी यात्राएँ चुनें।',
              ),
              icon: Icons.search_off,
            )
          else
            TransporterCardGrid(
              children: [for (final row in visible) _tile(row)],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> e) {
    final l = AppLocalizations.of(context)!;
    final status = (e['status'] ?? '').toString();
    final done = status == 'completed';
    final assigned = (e['vehicle_number'] ?? '').toString().isNotEmpty;
    return TransporterTaskCard(
      title: '${e['origin']} → ${e['destination_town']}',
      icon: Icons.local_shipping_outlined,
      description: l.tpCasesWeight(
        '${e['cases'] ?? 0}',
        '${e['weight_kg'] ?? 0}',
      ),
      status: StatusBadge(
        label:
            done
                ? l.tpCompleted
                : status == 'locked'
                ? tpText(context, 'Review delivery', 'डिलीवरी की समीक्षा करें')
                : status == 'dispatched'
                ? l.tpDispatched
                : l.tpAwarded,
        tone: done ? WorkspaceTone.success : WorkspaceTone.info,
      ),
      details: Text(
        [
          if (assigned)
            '${tpText(context, 'Vehicle', 'वाहन')}: ${e['vehicle_number']}',
          if ((e['driver_name'] ?? '').toString().isNotEmpty)
            '${tpText(context, 'Driver', 'ड्राइवर')}: ${e['driver_name']}',
          tpText(
            context,
            done
                ? 'Review the delivery record and proof.'
                : assigned
                ? 'Keep the office informed as the trip progresses.'
                : 'Start by confirming the vehicle and driver.',
            done
                ? 'डिलीवरी और प्रमाण का विवरण देखें।'
                : assigned
                ? 'यात्रा की स्थिति कार्यालय को बताते रहें।'
                : 'पहले वाहन और ड्राइवर की जानकारी दें।',
          ),
        ].join('\n'),
        style: const TextStyle(height: 1.5),
      ),
      actionLabel: tpText(
        context,
        done
            ? 'View delivery record'
            : assigned
            ? 'Update trip'
            : 'Confirm vehicle & driver',
        done
            ? 'डिलीवरी विवरण देखें'
            : assigned
            ? 'यात्रा अपडेट करें'
            : 'वाहन और ड्राइवर तय करें',
      ),
      onTap: () => context.push('/bid/${e['id']}/after'),
    );
  }
}
