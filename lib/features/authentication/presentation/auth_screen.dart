import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/core/theme/app_colors.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await ref.read(sessionControllerProvider.notifier).refresh();
      if (!mounted) return;
      final prompted = await ref.read(localDatabaseProvider).getState('notification_prompted');
      if (mounted) context.go(prompted == 'true' ? '/home' : '/permissions');
    } catch (error) {
      setState(() {
        _error = error is AppFailure ? error.message : 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            Text(_register ? 'Create account' : 'Sign in', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Cloud sync needs an account. You can still set reminders on this device without one.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (_register) ...[
              AppTextField(label: 'Your name', controller: _name, textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
            ],
            AppTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Password',
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.missed, fontSize: 16)),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: _busy ? 'Please wait…' : (_register ? 'Create account' : 'Sign in'),
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (_register) {
                        await auth.registerWithEmail(
                          email: _email.text,
                          password: _password.text,
                          displayName: _name.text,
                        );
                      } else {
                        await auth.signInWithEmail(email: _email.text, password: _password.text);
                      }
                    }),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register ? 'I already have an account' : 'Create an account'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => auth.requestPasswordReset(_email.text.trim())),
              child: const Text('Forgot password?'),
            ),
            const Divider(height: 32),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(() => auth.signInWithGoogle()),
              child: const Text('Continue with Google'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(() => auth.signInWithApple()),
              child: const Text('Continue with Apple'),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Continue without an account',
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final tz = await FlutterTimezone.getLocalTimezone();
                      await auth.continueAsGuest(timeZone: tz);
                    }),
            ),
          ],
        ),
      ),
    );
  }
}
