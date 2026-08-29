import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medipulse/core/constants/app_constants.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/routing/app_router.dart';
import 'package:medipulse/core/theme/app_theme.dart';

class MediPulseApp extends ConsumerWidget {
  const MediPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final user = ref.watch(sessionControllerProvider).valueOrNull;
    final highContrast = user?.highContrast ?? false;
    final textScale = user?.largeText == true ? 1.15 : 1.0;
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(highContrast: highContrast, textScale: textScale),
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1) * textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
