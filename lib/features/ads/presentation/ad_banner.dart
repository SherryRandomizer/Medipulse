import 'package:flutter/material.dart';
import 'package:medipulse/core/theme/app_colors.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class NonIntrusiveAdBanner extends StatelessWidget {
  const NonIntrusiveAdBanner({
    super.key,
    required this.subscription,
    required this.ads,
    this.criticalContext = false,
  });

  final Subscription subscription;
  final AdService ads;
  final bool criticalContext;

  @override
  Widget build(BuildContext context) {
    if (criticalContext || !ads.adsEnabledFor(subscription)) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: 'Advertisement',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Sponsored (free plan). Ads never appear on dose confirmation.'),
      ),
    );
  }
}
