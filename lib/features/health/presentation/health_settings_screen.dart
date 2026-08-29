import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/features/health/domain/health_sync.dart';
import 'package:medipulse/l10n/app_localizations.dart';

class HealthSettingsScreen extends ConsumerStatefulWidget {
  const HealthSettingsScreen({super.key});

  @override
  ConsumerState<HealthSettingsScreen> createState() => _HealthSettingsScreenState();
}

class _HealthSettingsScreenState extends ConsumerState<HealthSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).valueOrNull;
    final health = ref.watch(healthSyncServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthTitle)),
      body: user == null
          ? const SizedBox.shrink()
          : FutureBuilder(
              future: health.prefs(user.id),
              builder: (context, snapshot) {
                final prefs = snapshot.data ?? health.defaultPrefs(user.id);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(l10n.healthIntro),
                    const SizedBox(height: 12),
                    Text(l10n.nativeHealthUnavailable),
                    SwitchListTile(
                      title: Text(l10n.healthEnabled),
                      value: prefs.enabled,
                      onChanged: (enabled) async {
                        await health.savePrefs(
                          HealthSyncPreference(
                            userId: user.id,
                            enabled: enabled,
                            includeMedicineNames: prefs.includeMedicineNames,
                            updatedAt: clock.now().toUtc(),
                          ),
                        );
                        await ref.read(analyticsServiceProvider).logEvent('health_sync_toggled');
                        setState(() {});
                      },
                    ),
                    SwitchListTile(
                      title: Text(l10n.healthIncludeNames),
                      value: prefs.includeMedicineNames,
                      onChanged: (includeNames) async {
                        await health.savePrefs(
                          HealthSyncPreference(
                            userId: user.id,
                            enabled: prefs.enabled,
                            includeMedicineNames: includeNames,
                            updatedAt: clock.now().toUtc(),
                          ),
                        );
                        setState(() {});
                      },
                    ),
                    Text(l10n.wearableNotice),
                  ],
                );
              },
            ),
    );
  }
}
