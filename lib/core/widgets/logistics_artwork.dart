import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// An illustration layer for operational headers. Content sets the height;
/// artwork never participates in semantics or intercepts controls.
class LogisticsArtwork extends StatelessWidget {
  const LogisticsArtwork({
    super.key,
    required this.child,
    this.dark = false,
    this.borderRadius = 24,
  });

  static const asset = 'assets/branding/logistics-hero.png';
  final Widget child;
  final bool dark;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = dark ? AppColors.primary : AppColors.surfaceTint;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: base,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        base,
                        base.withValues(alpha: dark ? .90 : .97),
                        base.withValues(alpha: dark ? .25 : .78),
                      ],
                      stops: const [0, .48, 1],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
