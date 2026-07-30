import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/bid_date_label.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

/// Body-only version used inside [TransporterShell].
class TransporterHomeBody extends StatefulWidget {
  const TransporterHomeBody({super.key});

  @override
  State<TransporterHomeBody> createState() => _TransporterHomeBodyState();
}

class _TransporterHomeBodyState extends State<TransporterHomeBody> {
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.person_outline, color: _onSurface),
                onPressed: () => context.push('/profile'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _displayName.isEmpty ? 'Welcome' : 'Welcome, $_displayName',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: _onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadName,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SectionTitle(
                  title: 'Latest bids',
                  onTap: () => context.go('/bids'),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FreightsRepo.instance.streamOpenFreights(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final freights = snap.data!;
                    if (freights.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Text(
                          'No open bids right now. Check back soon.',
                          style: TextStyle(color: _onSurfaceVariant),
                        ),
                      );
                    }
                    return Column(
                      children:
                          freights.map((f) {
                            final v = freightView(f);
                            return _BidTile(
                              route: v['route'] as String,
                              summary:
                                  '${v['cases']} Cases · ${v['weight_kg']} Ton',
                              minsLeft: v['minsLeft'] as int,
                              date: v['created'] as DateTime?,
                              onTap: () => context.push('/bid/${v['id']}'),
                            );
                          }).toList(),
                    );
                  },
                ),
                _SectionTitle(
                  title: 'Won bids',
                  onTap: () => context.go('/fleet'),
                ),
                const _WonBidsStrip(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 22, 16, 8),
                  child: Text(
                    'Quick options',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: _onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width < 430 ? 2 : 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.88,
                    children: [
                      _QuickOption(
                        icon: Icons.local_shipping_outlined,
                        title: 'Vehicles',
                        subtitle: 'Add or delete',
                        onTap: () => context.push('/vehicles'),
                      ),
                      _QuickOption(
                        icon: Icons.history_outlined,
                        title: 'Bid history',
                        subtitle: 'Won and active',
                        onTap: () => context.go('/fleet'),
                      ),
                      _QuickOption(
                        icon: Icons.badge_outlined,
                        title: 'Drivers',
                        subtitle: 'Per vehicle',
                        onTap: () => context.push('/drivers'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: _onSurface,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward, color: _onSurface),
          ],
        ),
      ),
    );
  }
}

class _WonBidsStrip extends StatelessWidget {
  const _WonBidsStrip();

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.user?.id;
    if (uid == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('freights')
          .select(
            'id, origin, destination_town, status, vehicle_number, driver_name',
          )
          .eq('winner_profile_id', uid)
          .order('dispatched_at', ascending: false)
          .limit(6)
          .then((rows) => (rows as List).cast<Map<String, dynamic>>()),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 116,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EDFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Won bids will appear here after a freight is awarded.',
                style: TextStyle(color: _onSurfaceVariant),
              ),
            ),
          );
        }
        return SizedBox(
          height: 142,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final row = rows[i];
              final route = '${row['origin']} → ${row['destination_town']}';
              final vehicle = (row['vehicle_number'] ?? '').toString();
              return InkWell(
                onTap: () => context.push('/bid/${row['id']}/after'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 154,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE6F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFFB39DC8),
                        size: 34,
                      ),
                      const Spacer(),
                      Text(
                        route.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vehicle.isEmpty ? 'Awaiting vehicle' : vehicle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _QuickOption extends StatelessWidget {
  const _QuickOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFECE6F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 42, color: const Color(0xFFB39DC8)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _onSurface,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
        ],
      ),
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

  String get _label {
    if (minsLeft <= 0) return 'Closed';
    if (minsLeft >= 60) return '${minsLeft ~/ 60} hr ${minsLeft % 60} min left';
    return '$minsLeft min left';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = minsLeft > 0 && minsLeft < 30;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BidDateLabel(date: date),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EDFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECE6F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 28,
                      color: Color(0xFFB39DC8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: _onSurface,
                          ),
                        ),
                        Text(
                          summary,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: _onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _label,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    urgent
                                        ? const Color(0xFFB3261E)
                                        : _onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _onSurface),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
