import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/widgets/language_button.dart';
import 'package:kaysons_logistics/l10n/app_language.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Hindi selection changes visible UI and survives reload', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguage.instance.load();
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: AppLanguage.instance,
        builder: (context, _) => MaterialApp(
          locale: AppLanguage.instance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  Text(AppLocalizations.of(context)!.welcomeTitle),
                  const LanguageButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Never miss a freight'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('कोई माल ढुलाई न छूटे'), findsOneWidget);

    await AppLanguage.instance.load();
    expect(AppLanguage.instance.locale?.languageCode, 'hi');
    expect(find.text('कोई माल ढुलाई न छूटे'), findsOneWidget);
  });
}
