import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/widgets/app_components.dart';
import 'package:medipulse/shared/widgets/medication_widgets.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meds = ref.watch(medicationsListProvider(_query.text));
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(title: 'Medications', subtitle: 'Search by name, generic name, or doctor.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppTextField(
                label: 'Search',
                controller: _query,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: meds.when(
                loading: () => const LoadingState(),
                error: (_, _) => ErrorState(
                  message: 'We could not load your medications.',
                  onRetry: () => ref.invalidate(medicationsListProvider(_query.text)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyState(
                      title: 'No medications yet',
                      message: 'Add a medicine, choose the dose and time, then save.',
                      actionLabel: 'Add medication',
                      onAction: () => context.push('/medications/add'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final med = items[index];
                      return MedicationCard(
                        medication: med,
                        onTap: () => context.push('/medications/${med.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationDetailScreen extends ConsumerWidget {
  const MedicationDetailScreen({super.key, required this.medicationId});
  final String medicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(medicationRepositoryProvider).getById(medicationId),
      builder: (context, snapshot) {
        final med = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingState());
        }
        if (med == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorState(message: 'That medication is no longer available.'),
          );
        }
        final refill = ref.read(refillCalculatorProvider).estimate(med);
        return Scaffold(
          appBar: AppBar(title: Text(med.name)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _row('Strength', med.strength ?? 'Not entered'),
              _row('Dose', med.doseLabel),
              _row('Form', med.form.label),
              _row('Schedule', med.schedule.frequency.label),
              _row('Instructions', med.foodInstruction ?? 'None'),
              _row('Additional', med.additionalInstructions ?? 'None'),
              _row('Start', med.startDate.toLocal().toString().split(' ').first),
              _row('End', med.endDate?.toLocal().toString().split(' ').first ?? 'No end date'),
              _row(
                'Remaining',
                refill.remainingDoses == null
                    ? 'Not tracked'
                    : 'Approximately ${refill.remainingDoses} doses remaining.',
              ),
              _row('Doctor', med.doctorName ?? 'Not entered'),
              _row('Status', med.status.name),
              const SizedBox(height: 16),
              AppButton(label: 'Edit', onPressed: () => context.push('/medications/${med.id}/edit')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.push('/medications/${med.id}/refill'),
                child: const Text('Update supply'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _setStatus(context, ref, med, med.isPaused ? MedicationStatus.active : MedicationStatus.paused),
                child: Text(med.isPaused ? 'Resume' : 'Pause'),
              ),
              OutlinedButton(
                onPressed: () => _setStatus(context, ref, med, MedicationStatus.archived),
                child: const Text('Archive'),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await ConfirmationDialog.show(
                    context,
                    title: 'Delete this medication?',
                    message: 'History is kept unless you confirm. Prefer archive if you may need this again.',
                    confirmLabel: 'Delete',
                  );
                  if (!ok) return;
                  await ref.read(medicationRepositoryProvider).save(
                    med.copyWith(status: MedicationStatus.archived, deletedAt: DateTime.now().toUtc()),
                  );
                  if (context.mounted) context.go('/medications');
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    Medication med,
    MedicationStatus status,
  ) async {
    final updated = med.copyWith(status: status);
    await ref.read(medicationCoordinatorProvider).saveMedication(updated);
    ref.invalidate(homeSnapshotProvider);
    if (context.mounted) Navigator.pop(context);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
