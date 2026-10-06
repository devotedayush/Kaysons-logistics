import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/enrollment_strings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final session = AuthService.instance.session;
      if (session == null) {
        context.go('/welcome');
        return;
      }
      late final AppRole role;
      try {
        role = await AuthService.instance.requireApprovedAccess();
      } catch (_) {
        if (!mounted) return;
        context.go('/login');
        return;
      }
      if (!mounted) return;
      context.go(routeForRole(role));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/branding/kaysons-app-icon.png',
                width: 120,
                height: 120,
                semanticLabel: 'Kaysons logo',
              ),
              const SizedBox(height: 16),
              Text(
                'Kaysons Logistics',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                enrollmentText(
                  context,
                  'Opening your workspace…',
                  'आपका कार्यस्थल खुल रहा है…',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
