import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';

class FleetBody extends StatefulWidget {
  const FleetBody({super.key});

  @override
  State<FleetBody> createState() => _FleetBodyState();
}

class _FleetBodyState extends State<FleetBody> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'My fleet',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D1B20),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Manage vehicles',
                onPressed: () => context.push('/vehicles'),
                icon: const Icon(Icons.local_shipping_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: InkWell(
            onTap: () => context.push('/vehicles'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EDFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Color(0xFF6750A4)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add, edit, or delete vehicle and driver details',
                      style: TextStyle(
                        color: Color(0xFF1D1B20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Color(0xFF1D1B20)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "You haven't won any bids yet. Slide over to Bids.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF49454F)),
                      ),
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _entries.length,
                      separatorBuilder:
                          (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFCAC4D0),
                          ),
                      itemBuilder: (_, i) => _tile(_entries[i]),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> e) {
    final status = (e['status'] ?? '') as String;
    final route = '${e['origin']} → ${e['destination_town']}';
    final vehicle = (e['vehicle_number'] ?? '').toString();
    final driver = (e['driver_name'] ?? '').toString();
    final summary = [
      '${e['cases'] ?? 0} QT · ${e['weight_kg'] ?? 0} WT',
      if (vehicle.isNotEmpty) vehicle,
      if (driver.isNotEmpty) driver,
    ].join(' · ');
    return InkWell(
      onTap: () => context.push('/bid/${e['id']}/after'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFECE6F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 24,
                color: Color(0xFFB39DC8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF49454F),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1D1B20),
                    ),
                  ),
                  Text(
                    summary,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF49454F),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF1D1B20)),
          ],
        ),
      ),
    );
  }
}
