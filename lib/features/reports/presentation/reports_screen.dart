import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/theme/app_colors.dart';
import 'package:medipulse/shared/widgets/app_components.dart';
import 'package:medipulse/shared/widgets/medication_widgets.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  ({DateTime from, DateTime to}) _week() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    return (from: from, to: DateTime(now.year, now.month, now.day, 23, 59, 59));
  }

  ({DateTime from, DateTime to}) _month() {
    final now = DateTime.now();
    return (
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(rangeAdherenceProvider(_week()));
    final month = ref.watch(rangeAdherenceProvider(_month()));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const AppHeader(
              title: 'Reports',
              subtitle: 'Informational adherence only. PDF export arrives in a later phase.',
            ),
            week.when(
              loading: () => const LoadingState(message: 'Calculating this week…'),
              error: (_, _) => const ErrorState(message: 'Could not calculate weekly adherence.'),
              data: (summary) => AdherenceCard(title: 'This week', summary: summary),
            ),
            const SizedBox(height: 12),
            month.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (summary) => AdherenceCard(title: 'This month', summary: summary),
            ),
            const SizedBox(height: 16),
            month.maybeWhen(
              data: (summary) {
                if (summary.completed == 0) return const SizedBox.shrink();
                return SizedBox(
                  height: 220,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 48,
                          sections: [
                            PieChartSectionData(value: summary.taken.toDouble(), color: AppColors.taken, title: 'Taken'),
                            PieChartSectionData(value: summary.missed.toDouble(), color: AppColors.missed, title: 'Missed'),
                            PieChartSectionData(value: summary.skipped.toDouble(), color: AppColors.skipped, title: 'Skipped'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Text(LegalCopy.reportDisclaimer, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
