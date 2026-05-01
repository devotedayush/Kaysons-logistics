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
      PrimaryButtonStyle.filledBlack => (AppColors.black, Colors.white, null),
      PrimaryButtonStyle.filledPurple => (AppColors.primary, Colors.white, null),
      PrimaryButtonStyle.outlined => (
          Colors.white,
          AppColors.black,
          const BorderSide(color: Color(0x33000000)),
        ),
    };

    return SizedBox(
      height: 56,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: border ?? BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
