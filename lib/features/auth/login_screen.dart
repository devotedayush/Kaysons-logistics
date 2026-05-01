import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@') || password.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.signInWithPassword(email: email, password: password);
      final role = await AuthService.instance.fetchRole();
      if (!mounted) return;
      context.go(routeForRole(role));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in with your registered email and password.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF757575),
                        height: 16 / 11),
                  ),
                  const SizedBox(height: 40),
                  const Text('Email',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  PillTextField(
                    controller: _email,
                    hint: 'abc@gmail.com',
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  const Text('Password',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  PillTextField(
                    controller: _password,
                    hint: 'Password',
                    obscureText: true,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: PrimaryButton(
                      label: _busy ? 'Signing in…' : 'Sign in',
                      onPressed: _busy ? null : _submit,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('No account? Register'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
