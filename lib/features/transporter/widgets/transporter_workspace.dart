import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

String tpText(BuildContext context, String en, String hi) =>
    Localizations.localeOf(context).languageCode == 'hi' ? hi : en;

bool _isPhone(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

String tpResponsiveText(
  BuildContext context, {
  required String desktopEn,
  required String desktopHi,
  required String mobileEn,
  required String mobileHi,
}) =>
    _isPhone(context)
        ? tpText(context, mobileEn, mobileHi)
        : tpText(context, desktopEn, desktopHi);

String? tpDesktopOnlyText(BuildContext context, String en, String hi) =>
    _isPhone(context) ? null : tpText(context, en, hi);

EdgeInsets transporterPagePadding(BuildContext context) =>
    _isPhone(context)
        ? const EdgeInsets.fromLTRB(12, 12, 12, 24)
        : const EdgeInsets.all(20);

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
      final phone = _isPhone(context);
      return Wrap(
        spacing: 16,
        runSpacing: phone ? 12 : 16,
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
  Widget build(BuildContext context) {
    final phone = _isPhone(context);
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: phone ? 14 : 18,
          vertical: phone ? 12 : 18,
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final phone = _isPhone(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(phone ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primary, size: phone ? 23 : 26),
                SizedBox(width: phone ? 9 : 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: phone ? 2 : null,
                    overflow: phone ? TextOverflow.ellipsis : null,
                    style: TextStyle(
                      fontSize: phone ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      height: phone ? 1.2 : 1.3,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: phone ? 6 : 12),
            Text(
              description,
              style: TextStyle(
                fontSize: phone ? 14 : 15,
                height: phone ? 1.35 : 1.5,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (status != null) ...[SizedBox(height: phone ? 8 : 12), status!],
            if (details != null) ...[
              SizedBox(height: phone ? 8 : 12),
              details!,
            ],
            SizedBox(height: phone ? 10 : 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, phone ? 48 : 50),
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
}
