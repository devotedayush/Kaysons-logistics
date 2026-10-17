import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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
    this.compact = false,
  });

  final int rangeDays;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<int> onSelectRange;
  final Future<void> Function() onPickStart;
  final Future<void> Function() onPickEnd;
  final VoidCallback onClearCustom;
  final bool compact;

  String _customLabel(AppLocalizations l) {
    if (customStart == null || customEnd == null) {
      return l.dateWindowCustomDates;
    }
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${fmt(customStart!)} - ${fmt(customEnd!)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hasCustom = customStart != null && customEnd != null;
    if (compact) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<int>(
                  initialValue: hasCustom ? null : rangeDays,
                  onSelected: onSelectRange,
                  itemBuilder:
                      (_) => [
                        for (final days in [7, 15, 30, 90])
                          CheckedPopupMenuItem(
                            value: days,
                            checked: !hasCustom && rangeDays == days,
                            child: Text(l.dateWindowDays(days)),
                          ),
                      ],
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasCustom
                                ? _customLabel(l)
                                : l.dateWindowDays(rangeDays),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: onPickStart,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(l.dateWindowCustomDates),
                ),
              ),
            ],
          ),
          if (hasCustom)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                    onPressed: onPickStart,
                    child: Text(l.dateWindowFrom),
                  ),
                  TextButton(onPressed: onPickEnd, child: Text(l.dateWindowTo)),
                  TextButton(
                    onPressed: onClearCustom,
                    child: Text(l.dateWindowUsePreset),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RangeChip(
              label: l.dateWindowDays(7),
              selected: !hasCustom && rangeDays == 7,
              onTap: () => onSelectRange(7),
            ),
            _RangeChip(
              label: l.dateWindowDays(15),
              selected: !hasCustom && rangeDays == 15,
              onTap: () => onSelectRange(15),
            ),
            _RangeChip(
              label: l.dateWindowDays(30),
              selected: !hasCustom && rangeDays == 30,
              onTap: () => onSelectRange(30),
            ),
            _RangeChip(
              label: l.dateWindowDays(90),
              selected: !hasCustom && rangeDays == 90,
              onTap: () => onSelectRange(90),
            ),
            _RangeChip(
              label: _customLabel(l),
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
                label: Text(l.dateWindowFrom),
              ),
              OutlinedButton.icon(
                onPressed: onPickEnd,
                icon: const Icon(Icons.event_available_outlined, size: 16),
                label: Text(l.dateWindowTo),
              ),
              TextButton(
                onPressed: onClearCustom,
                child: Text(l.dateWindowUsePreset),
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
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                fontSize: 14,
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
    final start = DateTime(
      customStart.year,
      customStart.month,
      customStart.day,
    );
    final end = DateTime(
      customEnd.year,
      customEnd.month,
      customEnd.day,
      23,
      59,
      59,
    );
    return !local.isBefore(start) && !local.isAfter(end);
  }
  final now = DateTime.now();
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: rangeDays - 1));
  return !local.isBefore(start);
}
