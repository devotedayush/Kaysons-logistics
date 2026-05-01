import 'package:flutter/material.dart';

import 'core/routing/app_router.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const KaysonsApp());
}

class KaysonsApp extends StatelessWidget {
  const KaysonsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kaysons Logistics',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
