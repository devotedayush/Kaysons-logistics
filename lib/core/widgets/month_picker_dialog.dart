import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Keeps a draft month until Apply. Dismissing the route returns no selection.
class MonthPickerDialog extends StatefulWidget {
  const MonthPickerDialog({
    super.key,
    required this.initialMonth,
    required this.years,
  });

  final DateTime initialMonth;
  final List<int> years;

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _year = widget.initialMonth.year;
  late int _month = widget.initialMonth.month;
  late final List<int> _years =
      {...widget.years, widget.initialMonth.year}.toList()..sort();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final yearIndex = _years.indexOf(_year);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.adminSelectMonth,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      material.formatMonthYear(DateTime(_year, _month)),
                      key: const Key('month-picker-selection'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          key: const Key('month-picker-previous-year'),
                          tooltip:
                              '${material.previousPageTooltip}: ${l.adminYear}',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed:
                              yearIndex > 0
                                  ? () => setState(
                                    () => _year = _years[yearIndex - 1],
                                  )
                                  : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l.adminYear,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                key: const Key('month-picker-year'),
                                value: _year,
                                isExpanded: true,
                                itemHeight: null,
                                items: [
                                  for (final year in _years.reversed)
                                    DropdownMenuItem(
                                      value: year,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 48,
                                        ),
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: Text(
                                            material.formatYear(DateTime(year)),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: (year) {
                                  if (year != null) {
                                    setState(() => _year = year);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('month-picker-next-year'),
                          tooltip:
                              '${material.nextPageTooltip}: ${l.adminYear}',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed:
                              yearIndex < _years.length - 1
                                  ? () => setState(
                                    () => _year = _years[yearIndex + 1],
                                  )
                                  : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final scale =
                            MediaQuery.textScalerOf(context).scale(15) / 15;
                        final columns = (constraints.maxWidth / (112 * scale))
                            .floor()
                            .clamp(1, 3);
                        final width =
                            (constraints.maxWidth - 8 * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var month = 1; month <= 12; month++)
                              SizedBox(
                                width: width,
                                child: Semantics(
                                  selected: month == _month,
                                  child: OutlinedButton(
                                    key: ValueKey('month-picker-$month'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(48, 56),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 12,
                                      ),
                                      backgroundColor:
                                          month == _month
                                              ? scheme.primaryContainer
                                              : scheme.surface,
                                      foregroundColor:
                                          month == _month
                                              ? scheme.onPrimaryContainer
                                              : scheme.onSurface,
                                      side: BorderSide(
                                        color:
                                            month == _month
                                                ? scheme.primary
                                                : scheme.outline,
                                      ),
                                    ),
                                    onPressed:
                                        () => setState(() => _month = month),
                                    child: Text(
                                      DateFormat.MMMM(
                                        locale,
                                      ).format(DateTime(_year, month)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: OverflowBar(
                spacing: 8,
                overflowSpacing: 8,
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('month-picker-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.adminCancel),
                  ),
                  FilledButton(
                    key: const Key('month-picker-apply'),
                    onPressed:
                        () =>
                            Navigator.of(context).pop(DateTime(_year, _month)),
                    child: Text(l.adminApply),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
