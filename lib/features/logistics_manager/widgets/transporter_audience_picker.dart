import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Matches the freight read rule: a non-empty selected list is an allowlist;
/// otherwise every approved transporter except excluded IDs may read the bid.
class TransporterAudiencePicker extends StatelessWidget {
  const TransporterAudiencePicker({
    super.key,
    required this.transporters,
    required this.selectedOnly,
    required this.selectedIds,
    required this.excludedIds,
    required this.onModeChanged,
    required this.onTransporterChanged,
  });

  final List<Map<String, dynamic>> transporters;
  final bool selectedOnly;
  final Set<String> selectedIds;
  final Set<String> excludedIds;
  final ValueChanged<bool> onModeChanged;
  final void Function(String id, bool checked) onTransporterChanged;

  static String nameFor(Map<String, dynamic> transporter) =>
      (transporter['business_name'] ??
              transporter['full_name'] ??
              transporter['email'] ??
              'Unnamed')
          .toString();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final visibleTransporters = [...transporters]
      ..sort((a, b) => nameFor(a).compareTo(nameFor(b)));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.opsWhoCanBid,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _AudienceChoice(
            title: l.opsAllApprovedTransporters,
            description: l.opsAllApprovedHint,
            selected: !selectedOnly,
            onTap: () {
              if (selectedOnly) onModeChanged(false);
            },
          ),
          const SizedBox(height: 8),
          _AudienceChoice(
            title: l.opsOnlySelectedTransporters,
            description: l.opsOnlySelectedHint,
            selected: selectedOnly,
            onTap: () {
              if (!selectedOnly) onModeChanged(true);
            },
          ),
          const SizedBox(height: 18),
          Text(
            selectedOnly ? l.opsChooseTransporters : l.opsExcludeTransporters,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            selectedOnly ? l.opsOnlySelectedHint : l.opsExcludeHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (visibleTransporters.isEmpty)
            Text(l.opsNoApprovedTransporters)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 680 ? 2 : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      visibleTransporters.map((transporter) {
                        final id = transporter['id'] as String;
                        final checked =
                            selectedOnly
                                ? selectedIds.contains(id)
                                : excludedIds.contains(id);
                        return SizedBox(
                          width: width,
                          child: Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: CheckboxListTile(
                              value: checked,
                              onChanged:
                                  (value) =>
                                      onTransporterChanged(id, value ?? false),
                              title: Text(
                                nameFor(transporter),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color:
                                      checked
                                          ? colors.primary
                                          : colors.outlineVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          const SizedBox(height: 12),
          Text(
            selectedOnly
                ? l.opsSelectedCount(selectedIds.length)
                : l.opsExcludedCount(excludedIds.length),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceChoice extends StatelessWidget {
  const _AudienceChoice({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
