import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.featureName});
  final String featureName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MediPulse Premium')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$featureName is included with Premium.', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Store billing is not hardcoded. When RevenueCat or Play/App Store products are configured, purchase and restore will unlock this device.',
            ),
            const Spacer(),
            AppButton(
              label: 'View plans',
              onPressed: () => context.push('/settings/subscription'),
            ),
          ],
        ),
      ),
    );
  }
}
