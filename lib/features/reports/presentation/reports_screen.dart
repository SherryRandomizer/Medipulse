import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/theme/app_colors.dart';
import 'package:medipulse/features/ads/presentation/ad_banner.dart';
import 'package:medipulse/features/reports/domain/report_pdf_builder.dart';
import 'package:medipulse/features/subscriptions/domain/premium_features.dart';
import 'package:medipulse/shared/widgets/app_components.dart';
import 'package:medipulse/shared/widgets/medication_widgets.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _from;
  late DateTime _to;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  ({DateTime from, DateTime to}) get _range => (from: _from, to: _to);

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final user = await ref.read(sessionControllerProvider.future);
      if (user == null) return;
      final sub = await ref.read(subscriptionServiceProvider).current(user.id);
      if (!PremiumFeatures.canExportPdf(sub)) {
        if (mounted) context.push('/paywall', extra: 'PDF reports');
        return;
      }
      final meds = await ref.read(medicationRepositoryProvider).list(user.id, includeArchived: true);
      final summary = await ref.read(rangeAdherenceProvider(_range).future);
      final bytes = await ReportPdfBuilder().build(
        patientName: user.displayName,
        from: _from,
        to: _to,
        medications: meds,
        summary: summary,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/medipulse-report.pdf');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: LegalCopy.reportDisclaimer));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekFrom = DateTime.now().subtract(const Duration(days: 6));
    final monthFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final week = ref.watch(
      rangeAdherenceProvider((
        from: DateTime(weekFrom.year, weekFrom.month, weekFrom.day),
        to: _to,
      )),
    );
    final month = ref.watch(
      rangeAdherenceProvider((
        from: monthFrom,
        to: _to,
      )),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const AppHeader(
              title: 'Reports',
              subtitle: 'Informational adherence only. Share a PDF with your clinician if you wish.',
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
                            PieChartSectionData(
                              value: summary.taken.toDouble().clamp(0.01, 9999),
                              color: AppColors.taken,
                              title: 'Taken',
                            ),
                            PieChartSectionData(
                              value: summary.missed.toDouble().clamp(0.01, 9999),
                              color: AppColors.missed,
                              title: 'Missed',
                            ),
                            PieChartSectionData(
                              value: summary.skipped.toDouble().clamp(0.01, 9999),
                              color: AppColors.skipped,
                              title: 'Skipped',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            ListTile(
              title: const Text('From'),
              subtitle: Text(_from.toLocal().toString().split(' ').first),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _from,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _from = picked);
              },
            ),
            ListTile(
              title: const Text('To'),
              subtitle: Text(_to.toLocal().toString().split(' ').first),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _to,
                  firstDate: _from,
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                }
              },
            ),
            AppButton(
              label: _exporting ? 'Preparing PDF…' : 'Share PDF report',
              onPressed: _exporting ? null : _export,
            ),
            const SizedBox(height: 16),
            Text(LegalCopy.reportDisclaimer, style: Theme.of(context).textTheme.bodyMedium),
            Consumer(
              builder: (context, ref, _) {
                final user = ref.watch(sessionControllerProvider).valueOrNull;
                if (user == null) return const SizedBox.shrink();
                return FutureBuilder(
                  future: ref.read(subscriptionServiceProvider).current(user.id),
                  builder: (context, snapshot) {
                    final sub = snapshot.data;
                    if (sub == null) return const SizedBox.shrink();
                    return NonIntrusiveAdBanner(
                      subscription: sub,
                      ads: ref.read(adServiceProvider),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
