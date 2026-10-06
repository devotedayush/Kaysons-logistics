import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_language.dart';
import 'l10n/app_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load();
  await initSupabase();
  runApp(const KaysonsApp());
}

class KaysonsApp extends StatelessWidget {
  const KaysonsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder:
          (context, _) => MaterialApp.router(
            title: 'Kaysons Logistics',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            locale: AppLanguage.instance.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            routerConfig: appRouter,
          ),
    );
  }
}
