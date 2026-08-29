import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medipulse/core/theme/app_colors.dart';
import 'package:medipulse/core/theme/app_spacing.dart';
import 'package:medipulse/shared/models/entities.dart';

class MedicationStatusBadge extends StatelessWidget {
  const MedicationStatusBadge({super.key, required this.status});
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      DoseStatus.taken => ('Taken', AppColors.taken, AppColors.takenSoft),
      DoseStatus.pending => ('Upcoming', AppColors.upcoming, AppColors.primarySoft),
      DoseStatus.missed => ('Missed', AppColors.missed, AppColors.missedSoft),
      DoseStatus.skipped => ('Skipped', AppColors.skipped, const Color(0xFFEEF0F2)),
      DoseStatus.snoozed => ('Snoozed', AppColors.snoozed, AppColors.snoozedSoft),
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class AdherenceCard extends StatelessWidget {
  const AdherenceCard({super.key, required this.summary, this.title = "Today's adherence"});
  final AdherenceSummary summary;
  final String title;

  @override
  Widget build(BuildContext context) {
    final value = summary.completed == 0 ? null : summary.percentage;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              value == null ? 'No doses yet today' : '${value.round()}%',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Taken ${summary.taken} · Missed ${summary.missed} · Skipped ${summary.skipped}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.medication,
    required this.onTap,
  });

  final Medication medication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medication.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      [
                        if (medication.strength != null && medication.strength!.isNotEmpty)
                          medication.strength!,
                        medication.doseLabel,
                        medication.schedule.frequency.label,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.item,
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
  });

  final TimelineItem item;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(item.dose.remindAt.toLocal());
    final canAct = item.dose.status == DoseStatus.pending || item.dose.status == DoseStatus.snoozed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(time, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                MedicationStatusBadge(status: item.dose.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.medication.name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              [
                item.medication.doseLabel,
                if (item.medication.foodInstruction != null &&
                    item.medication.foodInstruction!.isNotEmpty)
                  item.medication.foodInstruction!,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (canAct) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(onPressed: onTaken, child: const Text('Taken')),
                  OutlinedButton(onPressed: onSnooze, child: const Text('Snooze')),
                  TextButton(onPressed: onSkip, child: const Text('Skip')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MedicationTimeline extends StatelessWidget {
  const MedicationTimeline({
    super.key,
    required this.items,
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
  });

  final List<TimelineItem> items;
  final void Function(TimelineItem item) onTaken;
  final void Function(TimelineItem item) onSnooze;
  final void Function(TimelineItem item) onSkip;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReminderCard(
              item: item,
              onTaken: () => onTaken(item),
              onSnooze: () => onSnooze(item),
              onSkip: () => onSkip(item),
            ),
          ),
      ],
    );
  }
}
