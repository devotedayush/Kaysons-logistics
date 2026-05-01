import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/freights_repo.dart';
import '../../core/widgets/bid_date_label.dart';
import '../../core/widgets/date_window_bar.dart';

class BidsBody extends StatefulWidget {
  const BidsBody({super.key});

  @override
  State<BidsBody> createState() => _BidsBodyState();
}

class _BidsBodyState extends State<BidsBody> {
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
              'Open bids',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1D1B20),
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
            stream: FreightsRepo.instance.streamOpenFreights(),
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
                      'No open bids right now.',
                      style: TextStyle(color: Color(0xFF49454F)),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
    final minsLeft = v['minsLeft'] as int;
    final urgent = minsLeft > 0 && minsLeft < 30;
    final label =
        minsLeft <= 0
            ? 'Closed'
            : minsLeft >= 60
            ? '${minsLeft ~/ 60} hr ${minsLeft % 60} min left'
            : '$minsLeft min left';

    return InkWell(
      onTap: () => context.push('/bid/${v['id']}'),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BidDateLabel(date: v['created'] as DateTime?),
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
                        v['route'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1D1B20),
                        ),
                      ),
                      Text(
                        '${v['cases']} QT · ${v['weight_kg']} WT',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF49454F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Color(0xFF49454F),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  urgent
                                      ? const Color(0xFFB3261E)
                                      : const Color(0xFF49454F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF1D1B20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
