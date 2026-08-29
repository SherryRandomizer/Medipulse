import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/constants/app_constants.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/theme/app_colors.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const pages = [
    (Icons.alarm, 'Never miss an important dose.', 'Gentle reminders help you take each dose at the right time.'),
    (Icons.medication_outlined, 'Organize all your medications in one place.', 'Keep names, doses, and instructions together — clearly and calmly.'),
    (Icons.document_scanner_outlined, 'Scan prescriptions and medicine packages with AI.', 'You always confirm extracted details before anything is saved.'),
    (Icons.insights_outlined, 'Track adherence and share reports with your doctor.', 'See what was taken, missed, or skipped — this is not medical advice.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(localDatabaseProvider).setState('onboarding_complete', 'true');
    await ref.read(analyticsServiceProvider).logEvent('onboarding_complete');
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _finish, child: const Text('Skip')),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.$1, size: 72, color: AppColors.primary),
                        const SizedBox(height: 32),
                        Text(
                          page.$2,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.$3,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    Container(
                      width: i == _page ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.primary : AppColors.outline,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              AppButton(
                label: _page == pages.length - 1 ? 'Continue' : 'Next',
                onPressed: () {
                  if (_page == pages.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                AppConstants.tagline,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
