import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/features/caregivers/domain/caregiver_access_policy.dart';
import 'package:medipulse/features/subscriptions/domain/premium_features.dart';
import 'package:medipulse/l10n/app_localizations.dart';
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
  List<Caregiver> _linked = [];
  final Map<String, SharedAdherenceSnapshot> _shared = {};
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
    final linked = await service.linkedAsCaregiver(user.id);
    final shared = <String, SharedAdherenceSnapshot>{};
    for (final link in linked) {
      final snap = await service.sharedPercentFor(ownerUserId: link.ownerUserId, viewerUserId: user.id);
      if (snap != null) shared[link.ownerUserId] = snap;
    }
    if (!mounted) return;
    setState(() {
      _family = family;
      _caregivers = caregivers;
      _linked = linked;
      _shared
        ..clear()
        ..addAll(shared);
      _loading = false;
    });
  }

  Future<bool> _hasPremium() async {
    final user = await ref.read(sessionControllerProvider.future);
    if (user == null) return false;
    final sub = await ref.read(subscriptionServiceProvider).current(user.id);
    if (!PremiumFeatures.canUseFamily(sub) && mounted) {
      context.push('/paywall', extra: 'Family and caregiver sharing');
      return false;
    }
    return PremiumFeatures.canUseFamily(sub);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyTitle)),
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
                    if (!await _hasPremium()) return;
                    if (!mounted) return;
                    final user = await ref.read(sessionControllerProvider.future);
                    if (user == null) return;
                    final name = await _promptName('Profile name');
                    if (name == null) return;
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
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(caregiver.displayName),
                            subtitle: Text(
                              '${caregiver.relation.name} · ${caregiver.status.name}\nInvite code ${caregiver.inviteCode}',
                            ),
                            isThreeLine: true,
                          ),
                          SwitchListTile(
                            title: const Text('Missed-dose alerts'),
                            value: caregiver.canReceiveAdherenceAlerts,
                            onChanged: (value) async {
                              await ref.read(caregiverServiceProvider).setSharing(
                                caregiver,
                                share: value,
                                status: value
                                    ? CaregiverPermissionStatus.accepted
                                    : CaregiverPermissionStatus.revoked,
                                sharePercent: caregiver.shareAdherencePercent,
                              );
                              await _reload();
                            },
                          ),
                          SwitchListTile(
                            title: Text(l10n.sharePercent),
                            value: caregiver.shareAdherencePercent &&
                                caregiver.status == CaregiverPermissionStatus.accepted,
                            onChanged: (value) async {
                              await ref.read(caregiverServiceProvider).setSharing(
                                caregiver,
                                share: caregiver.shareAdherence,
                                sharePercent: value,
                                status: value || caregiver.shareAdherence
                                    ? CaregiverPermissionStatus.accepted
                                    : caregiver.status,
                              );
                              await _reload();
                            },
                          ),
                          OverflowBar(
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  await Clipboard.setData(ClipboardData(text: caregiver.inviteCode));
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(l10n.copyInvite)),
                                  );
                                },
                                child: Text(l10n.copyInvite),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref.read(caregiverServiceProvider).setSharing(
                                    caregiver,
                                    share: false,
                                    sharePercent: false,
                                    status: CaregiverPermissionStatus.revoked,
                                  );
                                  await _reload();
                                },
                                child: Text(l10n.revokeAccess),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                AppButton(
                  label: 'Invite caregiver',
                  onPressed: () async {
                    if (!await _hasPremium()) return;
                    final user = await ref.read(sessionControllerProvider.future);
                    if (user == null) return;
                    final name = await _promptName('Caregiver name');
                    if (name == null) return;
                    await ref.read(caregiverServiceProvider).invite(
                      ownerUserId: user.id,
                      displayName: name,
                      relation: CaregiverRelation.familyMember,
                    );
                    await ref.read(analyticsServiceProvider).logEvent('caregiver_invited');
                    await _reload();
                  },
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: l10n.joinInvite,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final user = await ref.read(sessionControllerProvider.future);
                    if (user == null) return;
                    final code = await _promptName(l10n.joinInvite);
                    if (code == null || code.isEmpty) return;
                    try {
                      await ref.read(caregiverServiceProvider).acceptInvite(
                        code: code.toUpperCase(),
                        caregiverUserId: user.id,
                      );
                      await ref.read(analyticsServiceProvider).logEvent('caregiver_invite_accepted');
                      await _reload();
                    } on AppFailure catch (error) {
                      messenger.showSnackBar(SnackBar(content: Text(error.message)));
                    }
                  },
                ),
                if (_linked.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Shared with you', style: Theme.of(context).textTheme.titleLarge),
                  const Text('Adherence percent only. Medicine names are never shown here.'),
                  for (final link in _linked)
                    ListTile(
                      title: Text(link.displayName),
                      subtitle: Text(
                        _shared[link.ownerUserId] == null
                            ? 'Adherence percent is not shared with you.'
                            : 'Last 7 days: ${_shared[link.ownerUserId]!.percentage.toStringAsFixed(0)}% (${_shared[link.ownerUserId]!.completedDoses} completed doses)',
                      ),
                    ),
                ],
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
