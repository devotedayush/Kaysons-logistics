import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

String tpText(BuildContext context, String en, String hi) =>
    Localizations.localeOf(context).languageCode == 'hi' ? hi : en;

/// Content-driven rows become two columns on laptops without fixed card heights.
class TransporterCardGrid extends StatelessWidget {
  const TransporterCardGrid({
    super.key,
    required this.children,
    this.breakpoint = 720,
  });
  final List<Widget> children;
  final double breakpoint;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= breakpoint ? 2 : 1;
      final width = (c.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class TransporterSearch extends StatelessWidget {
  const TransporterSearch({
    super.key,
    required this.label,
    required this.onChanged,
  });
  final String label;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.search),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(18),
    ),
  );
}

class TransporterTaskCard extends StatelessWidget {
  const TransporterTaskCard({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
    this.icon = Icons.arrow_forward,
    this.status,
    this.details,
  });
  final String title, description, actionLabel;
  final VoidCallback onTap;
  final IconData icon;
  final Widget? status, details;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (status != null) ...[const SizedBox(height: 12), status!],
          if (details != null) ...[const SizedBox(height: 12), details!],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward),
            label: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
