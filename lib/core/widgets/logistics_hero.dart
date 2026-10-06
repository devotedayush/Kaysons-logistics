import 'package:flutter/material.dart';

import 'logistics_artwork.dart';

/// Decorative artwork stays separate from labels, so Hindi and larger text
/// remain readable. Height follows the content rather than clipping it.
class LogisticsHero extends StatelessWidget {
  const LogisticsHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  static const asset = LogisticsArtwork.asset;

  @override
  Widget build(BuildContext context) {
    return LogisticsArtwork(
      dark: true,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder:
              (context, constraints) => SizedBox(
                width:
                    constraints.maxWidth > 600
                        ? constraints.maxWidth * .65
                        : constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFECE5F5),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 16),
                      action!,
                    ],
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
