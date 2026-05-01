import 'package:flutter/material.dart';

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: const Color(0xFF49454F)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF49454F),
          side: const BorderSide(color: Color(0x80000000)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        label: Text(label),
      ),
    );
  }
}
