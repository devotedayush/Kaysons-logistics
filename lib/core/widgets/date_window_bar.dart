import 'package:flutter/material.dart';

class DateWindowBar extends StatelessWidget {
  const DateWindowBar({
    super.key,
    required this.rangeDays,
    required this.customStart,
    required this.customEnd,
    required this.onSelectRange,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearCustom,
  });

  final int rangeDays;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<int> onSelectRange;
  final Future<void> Function() onPickStart;
  final Future<void> Function() onPickEnd;
  final VoidCallback onClearCustom;

  String get _customLabel {
    if (customStart == null || customEnd == null) return 'Custom dates';
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${fmt(customStart!)} - ${fmt(customEnd!)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = customStart != null && customEnd != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RangeChip(
              label: '7 days',
              selected: !hasCustom && rangeDays == 7,
              onTap: () => onSelectRange(7),
            ),
            _RangeChip(
              label: '15 days',
              selected: !hasCustom && rangeDays == 15,
              onTap: () => onSelectRange(15),
            ),
            _RangeChip(
              label: '30 days',
              selected: !hasCustom && rangeDays == 30,
              onTap: () => onSelectRange(30),
            ),
            _RangeChip(
              label: _customLabel,
              selected: hasCustom,
              onTap: onPickStart,
              icon: Icons.calendar_month_outlined,
            ),
          ],
        ),
        if (hasCustom) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPickStart,
                icon: const Icon(Icons.event_outlined, size: 16),
                label: const Text('From'),
              ),
              OutlinedButton.icon(
                onPressed: onPickEnd,
                icon: const Icon(Icons.event_available_outlined, size: 16),
                label: const Text('To'),
              ),
              TextButton(
                onPressed: onClearCustom,
                child: const Text('Use preset'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8DEF8) : Colors.white,
          border: Border.all(color: const Color(0xFFCAC4D0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFF1D1B20)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool withinDateWindow(
  DateTime? value, {
  required int rangeDays,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  if (value == null) return false;
  final local = value.toLocal();
  if (customStart != null && customEnd != null) {
    final start = DateTime(customStart.year, customStart.month, customStart.day);
    final end = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
    return !local.isBefore(start) && !local.isAfter(end);
  }
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: rangeDays - 1));
  return !local.isBefore(start);
}
