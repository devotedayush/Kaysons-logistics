import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum WorkspaceTone { neutral, info, success, warning, danger }

Color workspaceToneColor(WorkspaceTone tone) => switch (tone) {
  WorkspaceTone.neutral => AppColors.onSurfaceVariant,
  WorkspaceTone.info => AppColors.primary,
  WorkspaceTone.success => const Color(0xFF146C4B),
  WorkspaceTone.warning => const Color(0xFF86530D),
  WorkspaceTone.danger => AppColors.danger,
};

/// A page starts with its purpose and one obvious next action.
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.eyebrow,
    this.action,
    this.summary,
  });
  final String title;
  final String description;
  final IconData icon;
  final String? eyebrow;
  final Widget? action;
  final Widget? summary;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.outline),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null) ...[
                        Text(
                          eyebrow!,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              copy,
              if (action != null) ...[
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, child: action!),
              ],
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  if (action != null) ...[
                    const SizedBox(width: 24),
                    Flexible(child: action!),
                  ],
                ],
              ),
            if (summary != null) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 18),
              summary!,
            ],
          ],
        );
      },
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.description,
    this.action,
  });
  final String title;
  final String? description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      );
      return constraints.maxWidth < 480
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          )
          : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              if (action != null) ...[const SizedBox(width: 16), action!],
            ],
          );
    },
  );
}

class GuidanceCard extends StatelessWidget {
  const GuidanceCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.action,
    this.tone = WorkspaceTone.info,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final WorkspaceTone tone;
  @override
  Widget build(BuildContext context) {
    final color = workspaceToneColor(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        border: Border.all(color: color.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = WorkspaceTone.neutral,
  });
  final String label;
  final WorkspaceTone tone;
  @override
  Widget build(BuildContext context) {
    final color = workspaceToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class WorkspaceEmptyState extends StatelessWidget {
  const WorkspaceEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.surfaceTint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class WorkspaceSection extends StatelessWidget {
  const WorkspaceSection({
    super.key,
    required this.title,
    this.description,
    this.action,
    required this.children,
  });
  final String title;
  final String? description;
  final Widget? action;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.outline),
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: title,
            description: description,
            action: action,
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}

/// Gives long forms a real desktop layout and a comfortable mobile reading width.
class WorkspaceFormLayout extends StatelessWidget {
  const WorkspaceFormLayout({
    super.key,
    required this.content,
    this.aside,
    this.maxWidth = 1120,
    this.showAsideOnMobile = false,
  });
  final Widget content;
  final Widget? aside;
  final double maxWidth;
  final bool showAsideOnMobile;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (aside == null) return content;
          if (constraints.maxWidth < 820) {
            return showAsideOnMobile
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content, const SizedBox(height: 24), aside!],
                )
                : content;
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: aside!),
              const SizedBox(width: 28),
              Expanded(flex: 5, child: content),
            ],
          );
        },
      ),
    ),
  );
}
