import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/freights_repo.dart';
import '../../core/widgets/bid_date_label.dart';
import '../../core/widgets/date_window_bar.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class AdminBidsBody extends StatefulWidget {
  const AdminBidsBody({super.key});

  @override
  State<AdminBidsBody> createState() => _AdminBidsBodyState();
}

class _AdminBidsBodyState extends State<AdminBidsBody> {
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;

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
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'All bids',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: _onSurface,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FreightsRepo.instance.streamAllFreights(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final freights =
                  snap.data!
                      .where(
                        (row) => withinDateWindow(
                          DateTime.tryParse(
                            (row['created_at'] ?? '').toString(),
                          ),
                          rangeDays: _rangeDays,
                          customStart: _customStart,
                          customEnd: _customEnd,
                        ),
                      )
                      .toList();
              if (freights.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No bids found for this date window.',
                      style: TextStyle(color: _onSurfaceVariant),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: freights.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final v = freightView(freights[i]);
                  return _tile(context, v);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> v) {
    final status = v['status'] as String;
    final bg = switch (status) {
      'bidding' => const Color(0xFFF6EDFB),
      'awarded' || 'dispatched' => const Color(0xFFE1F5E1),
      'locked' || 'completed' => const Color(0xFFECE6F0),
      _ => const Color(0xFFF3F3F3),
    };
    return InkWell(
      onTap: () => context.push('/lm/bid/${v['id']}'),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BidDateLabel(date: v['created'] as DateTime?),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
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
                        v['route'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _onSurface,
                        ),
                      ),
                      Text(
                        '${v['cases']} QT · ${v['weight_kg']} WT',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _onSurfaceVariant,
                        ),
                      ),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: _onSurfaceVariant,
                        ),
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
    );
  }
}
