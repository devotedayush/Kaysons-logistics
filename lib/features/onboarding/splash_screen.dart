import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/theme/app_theme.dart';

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
      final role = await AuthService.instance.fetchRole();
      if (!mounted) return;
      context.go(routeForRole(role));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                'Kaysons',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
              ),
            ),
            const Positioned(
              bottom: 120,
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
