import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum PrimaryButtonStyle { filledBlack, filledPurple, outlined }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PrimaryButtonStyle.filledBlack,
  });

  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      PrimaryButtonStyle.filledBlack => (AppColors.primary, Colors.white, null),
      PrimaryButtonStyle.filledPurple => (AppColors.accent, Colors.white, null),
      PrimaryButtonStyle.outlined => (
        Colors.white,
        AppColors.primary,
        const BorderSide(color: AppColors.outline),
      ),
    };

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Material(
          color: onPressed == null ? AppColors.outline : bg,
          elevation:
              onPressed == null || style == PrimaryButtonStyle.outlined ? 0 : 2,
          shadowColor: AppColors.accent.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: border ?? BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: onPressed == null ? AppColors.onSurfaceVariant : fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
