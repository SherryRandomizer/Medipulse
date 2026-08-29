import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return session.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (_, _) => const Scaffold(body: ErrorState(message: 'Could not load your profile.')),
      data: (user) {
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const AppHeader(title: 'Profile'),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(user?.displayName.isEmpty ?? true ? 'Guest' : user!.displayName),
                    subtitle: Text(
                      user == null
                          ? ''
                          : user.isGuest
                          ? 'Reminders stay on this device until you create an account.'
                          : user.email,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings'),
                ),
                ListTile(
                  title: const Text('Family & caregivers'),
                  subtitle: const Text('Premium. Share missed-dose alerts you approve.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/family'),
                ),
                ListTile(
                  title: const Text('Health & wearables'),
                  subtitle: const Text('Opt in to dose-taken times. Native Health SDKs are not linked yet.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/health'),
                ),
                ListTile(
                  title: const Text('MediPulse AI'),
                  subtitle: const Text('Ask about your saved schedule only.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ai'),
                ),
                ListTile(
                  title: const Text('Subscription'),
                  subtitle: const Text('Free plan — billing adapter is ready for RevenueCat.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/subscription'),
                ),
                const SizedBox(height: 16),
                Text(LegalCopy.medicalDisclaimer, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        );
      },
    );
  }
}
