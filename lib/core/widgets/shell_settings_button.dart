import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';

class ShellSettingsButton extends StatelessWidget {
  const ShellSettingsButton({
    super.key,
    required this.onLogout,
    this.onProfile,
  });

  final Future<void> Function() onLogout;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final currentLanguage = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: l.profile,
      onSelected: (value) async {
        if (value == 'profile') {
          onProfile?.call();
        }
        if (value == 'privacy' && context.mounted) {
          context.push('/account/privacy');
        }
        if (value == 'logout') {
          await onLogout();
        }
        if (value == 'en' || value == 'hi') {
          await AppLanguage.instance.select(value);
        }
      },
      itemBuilder:
          (context) => [
            if (onProfile != null)
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18),
                    SizedBox(width: 10),
                    Text(l.profile),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'privacy',
              child: Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 18),
                  SizedBox(width: 10),
                  Text(l.accountPrivacy),
                ],
              ),
            ),
            CheckedPopupMenuItem<String>(
              value: 'en',
              checked: currentLanguage == 'en',
              child: Text('${l.language}: ${l.english}'),
            ),
            CheckedPopupMenuItem<String>(
              value: 'hi',
              checked: currentLanguage == 'hi',
              child: Text('${l.language}: ${l.hindi}'),
            ),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 10),
                  Text(l.logout),
                ],
              ),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9E1F1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 20,
              color: Color(0xFF49454F),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                onProfile == null ? l.logout : l.profile,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1B20),
                ),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: Color(0xFF49454F)),
          ],
        ),
      ),
    );
  }
}
