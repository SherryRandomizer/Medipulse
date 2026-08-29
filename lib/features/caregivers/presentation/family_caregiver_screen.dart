import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/features/caregivers/domain/caregiver_access_policy.dart';
import 'package:medipulse/features/subscriptions/domain/premium_features.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class FamilyCaregiverScreen extends ConsumerStatefulWidget {
  const FamilyCaregiverScreen({super.key});

  @override
  ConsumerState<FamilyCaregiverScreen> createState() => _FamilyCaregiverScreenState();
}

class _FamilyCaregiverScreenState extends ConsumerState<FamilyCaregiverScreen> {
  List<FamilyProfile> _family = [];
  List<Caregiver> _caregivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final user = await ref.read(sessionControllerProvider.future);
    if (user == null) return;
    final service = ref.read(caregiverServiceProvider);
    final family = await service.family(user.id);
    final caregivers = await service.list(user.id);
    if (!mounted) return;
    setState(() {
      _family = family;
      _caregivers = caregivers;
      _loading = false;
    });
  }

  Future<void> _requirePremium() async {
    final user = await ref.read(sessionControllerProvider.future);
    if (user == null) return;
    final sub = await ref.read(subscriptionServiceProvider).current(user.id);
    if (!PremiumFeatures.canUseFamily(sub) && mounted) {
      context.push('/paywall', extra: 'Family and caregiver sharing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family & caregivers')),
      body: _loading
          ? const LoadingState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(CaregiverAccessPolicy.description, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Text('Family profiles', style: Theme.of(context).textTheme.titleLarge),
                if (_family.isEmpty) const Text('No family profiles yet.'),
                for (final profile in _family)
                  ListTile(
                    title: Text(profile.displayName),
                    subtitle: Text(profile.relation.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref.read(caregiverServiceProvider).removeFamily(profile.id);
                        await _reload();
                      },
                    ),
                  ),
                AppButton(
                  label: 'Add family profile',
                  onPressed: () async {
                    await _requirePremium();
                    if (!mounted) return;
                    final user = await ref.read(sessionControllerProvider.future);
                    final sub = user == null ? null : await ref.read(subscriptionServiceProvider).current(user.id);
                    if (sub == null || !PremiumFeatures.canUseFamily(sub)) return;
                    final name = await _promptName('Profile name');
                    if (name == null || user == null) return;
                    await ref.read(caregiverServiceProvider).addFamily(
                      ownerUserId: user.id,
                      displayName: name,
                      relation: CaregiverRelation.familyMember,
                    );
                    await _reload();
                  },
                ),
                const SizedBox(height: 24),
                Text('Caregivers', style: Theme.of(context).textTheme.titleLarge),
                if (_caregivers.isEmpty) const Text('No caregivers yet.'),
                for (final caregiver in _caregivers)
                  Card(
                    child: ListTile(
                      title: Text(caregiver.displayName),
                      subtitle: Text(
                        '${caregiver.relation.name} · ${caregiver.status.name}\nInvite code ${caregiver.inviteCode}',
                      ),
                      isThreeLine: true,
                      trailing: Switch(
                        value: caregiver.canReceiveAdherenceAlerts,
                        onChanged: (value) async {
                          await ref.read(caregiverServiceProvider).setSharing(
                            caregiver,
                            share: value,
                            status: value
                                ? CaregiverPermissionStatus.accepted
                                : CaregiverPermissionStatus.revoked,
                          );
                          await _reload();
                        },
                      ),
                    ),
                  ),
                AppButton(
                  label: 'Invite caregiver',
                  onPressed: () async {
                    await _requirePremium();
                    final user = await ref.read(sessionControllerProvider.future);
                    final sub = user == null ? null : await ref.read(subscriptionServiceProvider).current(user.id);
                    if (sub == null || !PremiumFeatures.canUseFamily(sub) || user == null) return;
                    final name = await _promptName('Caregiver name');
                    if (name == null) return;
                    await ref.read(caregiverServiceProvider).invite(
                      ownerUserId: user.id,
                      displayName: name,
                      relation: CaregiverRelation.familyMember,
                    );
                    await _reload();
                  },
                ),
              ],
            ),
    );
  }

  Future<String?> _promptName(String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }
}
