import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  ConsumerState<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends ConsumerState<NotificationPermissionScreen> {
  bool _busy = false;

  Future<void> _decide(bool request) async {
    setState(() => _busy = true);
    if (request) {
      await ref.read(notificationServiceProvider).requestPermission();
      await ref.read(notificationServiceProvider).requestExactAlarms();
    }
    await ref.read(localDatabaseProvider).setState('notification_prompted', 'true');
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text('Allow reminders', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(
                'MediPulse uses notifications to remind you when it is time to take a medication — even if the app is closed.\n\nOn Android, exact alarms keep those reminders on time. Notifications are never used for marketing.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              AppButton(
                label: _busy ? 'Please wait…' : 'Turn on reminders',
                onPressed: _busy ? null : () => _decide(true),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(false),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
