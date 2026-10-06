import 'package:flutter/material.dart';

String officeCopy(BuildContext context, String english, String hindi) =>
    Localizations.localeOf(context).languageCode == 'hi' ? hindi : english;

/// Labeled values stay readable on a phone instead of requiring a wide table.
class OfficeRecordCard extends StatelessWidget {
  const OfficeRecordCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.values,
    this.status,
    this.actions,
    this.details,
  });
  final String title;
  final String? subtitle;
  final Map<String, String> values;
  final Widget? status, actions, details;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != null) ...[status!, const SizedBox(height: 10)],
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder:
                (context, constraints) => Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children:
                      values.entries
                          .map(
                            (entry) => SizedBox(
                              width:
                                  constraints.maxWidth < 300
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 16) / 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium?.copyWith(
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    entry.value,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
          ),
          if (actions != null) ...[const SizedBox(height: 16), actions!],
          if (details != null) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(officeCopy(context, 'More details', 'अधिक जानकारी')),
              children: [details!],
            ),
          ],
        ],
      ),
    ),
  );
}
