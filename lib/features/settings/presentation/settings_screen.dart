import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:medipulse/core/config/app_config.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/l10n/app_locales.dart';
import 'package:medipulse/l10n/app_localizations.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).valueOrNull;
    final prefs = ref.watch(prefsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsTitle)),
      body: ListView(
        children: [
          const ListTile(title: Text('Account'), dense: true),
          ListTile(
            title: const Text('Profile'),
            subtitle: Text(user?.displayName.isEmpty ?? true ? 'Add your name' : user!.displayName),
            onTap: () => context.push('/settings/profile'),
          ),
          ListTile(
            title: const Text('Notifications'),
            subtitle: prefs.maybeWhen(
              data: (p) => Text(p?.enabled == true ? 'Reminders on' : 'Reminders off'),
              orElse: () => const Text(''),
            ),
            onTap: () => context.push('/settings/notifications'),
          ),
          ListTile(
            title: const Text('Accessibility'),
            onTap: () => context.push('/settings/accessibility'),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context).languageTitle),
            subtitle: Text(AppLocales.labels[user?.preferredLanguage] ?? user?.preferredLanguage ?? 'en'),
            onTap: () => context.push('/settings/language'),
          ),
          const Divider(),
          const ListTile(title: Text('Privacy and security'), dense: true),
          ListTile(
            title: const Text('Privacy'),
            onTap: () => context.push('/legal/privacy'),
          ),
          ListTile(
            title: const Text('Security'),
            subtitle: Text(AppLocalizations.of(context).securitySubtitle),
            onTap: () {},
          ),
          ListTile(
            title: Text(AppLocalizations.of(context).healthTitle),
            subtitle: const Text('Apple Health, Health Connect, and wearables'),
            onTap: () => context.push('/settings/health'),
          ),
          ListTile(
            title: const Text('Export data'),
            onTap: () async {
              final current = user;
              if (current == null) return;
              final json = await ref.read(localDatabaseProvider).exportUserJson(current.id);
              final dir = await getApplicationDocumentsDirectory();
              final file = File('${dir.path}/medipulse-export.json');
              await file.writeAsString(json);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exported to ${file.path}')),
                );
              }
            },
          ),
          ListTile(
            title: const Text('Delete account'),
            onTap: () async {
              final ok = await ConfirmationDialog.show(
                context,
                title: 'Delete your account?',
                message: 'This removes local MediPulse data for this profile on this device.',
                confirmLabel: 'Delete',
              );
              if (!ok) return;
              await ref.read(authServiceProvider).deleteAccount();
              await ref.read(sessionControllerProvider.notifier).refresh();
              if (context.mounted) context.go('/auth');
            },
          ),
          const Divider(),
          const ListTile(title: Text('Subscription'), dense: true),
          ListTile(
            title: const Text('Subscription'),
            onTap: () => context.push('/settings/subscription'),
          ),
          ListTile(
            title: const Text('Restore purchases'),
            onTap: () async {
              await ref.read(subscriptionServiceProvider).restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No store billing is configured in this build.')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(title: const Text('Terms'), onTap: () => context.push('/legal/terms')),
          ListTile(title: const Text('Privacy Policy'), onTap: () => context.push('/legal/privacy')),
          ListTile(title: const Text('About'), onTap: () => context.push('/settings/about')),
          ListTile(
            title: const Text('Sign out'),
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              await ref.read(sessionControllerProvider.notifier).refresh();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  DateTime? _dob;
  String? _timeZone;
  String? _photoPath;

  static const _zones = [
    'UTC',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Berlin',
    'Asia/Karachi',
    'Asia/Kolkata',
    'Asia/Dubai',
    'Asia/Singapore',
    'Australia/Sydney',
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<String> _zoneOptions(String? current) {
    final extra = current == null || current.isEmpty || _zones.contains(current) ? <String>[] : [current];
    return [...extra, ..._zones];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).valueOrNull;
    if (user != null && _name.text.isEmpty) {
      _name.text = user.displayName;
      _dob ??= user.dateOfBirth;
      _timeZone ??= user.timeZone;
      _photoPath ??= user.photoPath;
    }
    final zones = _zoneOptions(_timeZone ?? user?.timeZone);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: _photoPath == null ? null : FileImage(File(_photoPath!)),
              child: _photoPath == null ? const Icon(Icons.person_outline, size: 40) : null,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: user == null
                ? null
                : () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (picked == null) return;
                    final dir = await getApplicationDocumentsDirectory();
                    final dest = File('${dir.path}/profile-photo.jpg');
                    await dest.writeAsBytes(await picked.readAsBytes());
                    setState(() => _photoPath = dest.path);
                  },
            child: const Text('Choose photo (stays on this device)'),
          ),
          AppTextField(label: 'Name', controller: _name),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth (optional)'),
            subtitle: Text(
              _dob == null ? 'Not set. Used only to personalize your profile.' : _dob!.toLocal().toString().split(' ').first,
            ),
            onTap: user == null
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dob ?? DateTime(1980, 1, 1),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _dob = picked);
                  },
          ),
          Text('Time zone', style: Theme.of(context).textTheme.titleMedium),
          for (final zone in zones)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(zone),
              trailing: (_timeZone ?? user?.timeZone) == zone ? const Icon(Icons.check) : null,
              onTap: () => setState(() => _timeZone = zone),
            ),
          const SizedBox(height: 12),
          const Text('We do not collect extra medical history.'),
          const SizedBox(height: 24),
          AppButton(
            label: 'Save',
            onPressed: user == null
                ? null
                : () async {
                    await ref.read(authServiceProvider).updateProfile(
                      user.copyWith(
                        displayName: _name.text.trim(),
                        dateOfBirth: _dob,
                        photoPath: _photoPath,
                        timeZone: _timeZone ?? user.timeZone,
                      ),
                    );
                    await ref.read(sessionControllerProvider.notifier).refresh();
                    if (context.mounted) Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: prefs.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(message: 'Could not load reminder settings.'),
        data: (value) {
          if (value == null) {
            return const EmptyState(title: 'No settings', message: 'Sign in or continue as a guest first.');
          }
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Reminders'),
                subtitle: const Text('Required for dose alerts when the app is closed.'),
                value: value.enabled,
                onChanged: (enabled) async {
                  await ref.read(localDatabaseProvider).upsertNotificationPreference(
                    value.copyWith(enabled: enabled, updatedAt: DateTime.now().toUtc()),
                  );
                  ref.invalidate(prefsProvider);
                },
              ),
              SwitchListTile(
                title: const Text('Sound'),
                value: value.soundEnabled,
                onChanged: (enabled) async {
                  await ref.read(localDatabaseProvider).upsertNotificationPreference(
                    value.copyWith(soundEnabled: enabled, updatedAt: DateTime.now().toUtc()),
                  );
                  ref.invalidate(prefsProvider);
                },
              ),
              SwitchListTile(
                title: const Text('Vibration'),
                value: value.vibrationEnabled,
                onChanged: (enabled) async {
                  await ref.read(localDatabaseProvider).upsertNotificationPreference(
                    value.copyWith(vibrationEnabled: enabled, updatedAt: DateTime.now().toUtc()),
                  );
                  ref.invalidate(prefsProvider);
                },
              ),
              const ListTile(
                title: Text('Snooze options'),
                subtitle: Text('5, 10, 30 minutes, and 1 hour'),
              ),
              FutureBuilder(
                future: Future.wait([
                  ref.read(notificationServiceProvider).hasPermission(),
                  ref.read(notificationServiceProvider).canScheduleExactAlarms(),
                ]),
                builder: (context, snapshot) {
                  final allowed = snapshot.data;
                  final notices = allowed == null
                      ? 'Checking reminder permissions…'
                      : 'Notifications: ${allowed[0] ? 'on' : 'off'}. Exact alarms: ${allowed[1] ? 'allowed' : 'not allowed (reminders may be late on Android)'}.';
                  return Column(
                    children: [
                      ListTile(subtitle: Text(notices)),
                      ListTile(
                        title: const Text('Allow exact alarms'),
                        subtitle: const Text('Keeps Android reminders on time. iOS does not use this setting.'),
                        onTap: () async {
                          await ref.read(notificationServiceProvider).requestExactAlarms();
                        },
                      ),
                      ListTile(
                        title: const Text('Open system notification settings'),
                        onTap: () => ref.read(notificationServiceProvider).openSystemNotificationSettings(),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Larger text'),
            value: user?.largeText ?? false,
            onChanged: user == null
                ? null
                : (value) async {
                    await ref.read(authServiceProvider).updateProfile(user.copyWith(largeText: value));
                    await ref.read(sessionControllerProvider.notifier).refresh();
                  },
          ),
          SwitchListTile(
            title: const Text('High contrast'),
            value: user?.highContrast ?? false,
            onChanged: user == null
                ? null
                : (value) async {
                    await ref.read(authServiceProvider).updateProfile(user.copyWith(highContrast: value));
                    await ref.read(sessionControllerProvider.notifier).refresh();
                  },
          ),
          const ListTile(
            subtitle: Text('MediPulse also follows your device text size and screen reader.'),
          ),
        ],
      ),
    );
  }
}

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: ListView(
        children: [
          for (final code in AppLocales.codes)
            ListTile(
              title: Text(AppLocales.labels[code]!),
              trailing: (user?.preferredLanguage ?? 'en') == code
                  ? const Icon(Icons.check)
                  : null,
              onTap: user == null
                  ? null
                  : () async {
                      await ref.read(authServiceProvider).updateProfile(
                        user.copyWith(preferredLanguage: code, updatedAt: DateTime.now().toUtc()),
                      );
                      await ref.read(sessionControllerProvider.notifier).refresh();
                    },
            ),
        ],
      ),
    );
  }
}

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(analyticsServiceProvider).logEvent('subscription_screen_viewed');
    final user = ref.watch(sessionControllerProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Free', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const Text('Basic reminders, limited medications, basic history, basic notifications.'),
          const SizedBox(height: 16),
          const Text('Premium', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const Text(
            'Unlimited medications, scanning, family profiles, PDF reports, cloud sync, caregiver alerts, and MediPulse AI. Status is stored per account — never hardcoded.',
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: user == null ? null : ref.read(subscriptionServiceProvider).current(user.id),
            builder: (context, snapshot) {
              final tier = snapshot.data?.tier.name ?? 'free';
              return Text('Current plan on this device: $tier');
            },
          ),
          const SizedBox(height: 16),
          if (config.environment == AppEnvironment.development && user != null)
            AppButton(
              label: 'Device testing only: set Premium',
              onPressed: () async {
                await ref.read(subscriptionServiceProvider).applyEntitlement(
                  Subscription(
                    userId: user.id,
                    tier: SubscriptionTier.premium,
                    productId: 'dev.local',
                    updatedAt: DateTime.now().toUtc(),
                  ),
                );
                await ref.read(analyticsServiceProvider).logEvent('subscription_started');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Premium saved on this device for testing. Not a store purchase.')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(appConfigProvider).crashReportingConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('MediPulse', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const Text('Never Miss Your Medicine.'),
          const SizedBox(height: 16),
          Text(LegalCopy.medicalDisclaimer),
          const SizedBox(height: 16),
          Text(
            configured
                ? 'Crash reports: on. Only redacted error types and MediPulse stack frames are sent. Medicine names are not included.'
                : 'Crash reports: off. Set SENTRY_DSN at build time to send redacted crash reports. Medicine names are never sent.',
          ),
        ],
      ),
    );
  }
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(body, style: const TextStyle(fontSize: 16, height: 1.4)),
      ),
    );
  }
}

