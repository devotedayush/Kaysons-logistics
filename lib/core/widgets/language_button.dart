import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final current = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: l.language,
      onSelected: AppLanguage.instance.select,
      itemBuilder:
          (context) => [
            CheckedPopupMenuItem<String>(
              value: 'en',
              checked: current == 'en',
              child: Text(l.english),
            ),
            CheckedPopupMenuItem<String>(
              value: 'hi',
              checked: current == 'hi',
              child: Text(l.hindi),
            ),
          ],
      child: Semantics(
        button: true,
        label: l.language,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_outlined, size: 20),
              const SizedBox(width: 6),
              Text(current == 'hi' ? 'हिंदी' : 'English'),
            ],
          ),
        ),
      ),
    );
  }
}
