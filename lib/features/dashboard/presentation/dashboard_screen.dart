import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medipulse/core/constants/app_constants.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/widgets/app_components.dart';
import 'package:medipulse/shared/widgets/medication_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _act(WidgetRef ref, BuildContext context, TimelineItem item, DoseStatus status) async {
    try {
      Duration? snooze;
      if (status == DoseStatus.snoozed) {
        snooze = await _pickSnooze(context, ref);
        if (snooze == null) return;
      }
      await ref.read(medicationCoordinatorProvider).actOnDose(item.dose, status, snooze: snooze);
      ref.invalidate(homeSnapshotProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is AppFailure ? error.message : 'Could not update that dose.')),
        );
      }
    }
  }

  Future<Duration?> _pickSnooze(BuildContext context, WidgetRef ref) async {
    final prefs = await ref.read(prefsProvider.future);
    final options = prefs?.snoozeMinutes ?? AppConstants.defaultSnoozeMinutes;
    if (!context.mounted) return null;
    return showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Snooze reminder')),
              for (final minutes in options)
                ListTile(
                  title: Text(minutes == 60 ? '1 hour' : '$minutes minutes'),
                  onTap: () => Navigator.pop(context, Duration(minutes: minutes)),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeSnapshotProvider);
    return async.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (error, _) => Scaffold(
        body: ErrorState(
          message: 'We could not load today\'s schedule.',
          onRetry: () => ref.invalidate(homeSnapshotProvider),
        ),
      ),
      data: (snapshot) {
        if (snapshot == null) {
          return const Scaffold(body: LoadingState());
        }
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(homeSnapshotProvider),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  AppHeader(
                    title: '${_greeting()}, ${snapshot.user.greetingName}',
                    subtitle: DateFormat.yMMMMEEEEd().format(DateTime.now()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AdherenceCard(summary: snapshot.summary),
                  ),
                  if (snapshot.nextItem != null) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text('Next medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ReminderCard(
                        item: snapshot.nextItem!,
                        onTaken: () => _act(ref, context, snapshot.nextItem!, DoseStatus.taken),
                        onSnooze: () => _act(ref, context, snapshot.nextItem!, DoseStatus.snoozed),
                        onSkip: () => _act(ref, context, snapshot.nextItem!, DoseStatus.skipped),
                      ),
                    ),
                  ],
                  if (snapshot.refillWarnings.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('Refill warnings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot.refillWarnings
                                    .map((m) => '${m.name} may run out soon.')
                                    .join('\n'),
                              ),
                              const SizedBox(height: 8),
                              Text(LegalCopy.refillDisclaimer, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text("Today's medications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  if (snapshot.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: EmptyState(
                        title: 'No doses scheduled today',
                        message: 'Add your first medication: name, dose, and time. Then save to get a reminder.',
                        actionLabel: 'Add medication',
                        onAction: () => context.push('/medications/add'),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: MedicationTimeline(
                        items: snapshot.items,
                        onTaken: (item) => _act(ref, context, item, DoseStatus.taken),
                        onSnooze: (item) => _act(ref, context, item, DoseStatus.snoozed),
                        onSkip: (item) => _act(ref, context, item, DoseStatus.skipped),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
