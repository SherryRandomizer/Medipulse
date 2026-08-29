import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/features/authentication/presentation/auth_screen.dart';
import 'package:medipulse/features/calendar/presentation/calendar_screen.dart';
import 'package:medipulse/features/dashboard/presentation/app_shell.dart';
import 'package:medipulse/features/dashboard/presentation/dashboard_screen.dart';
import 'package:medipulse/features/medications/presentation/add_medication_screen.dart';
import 'package:medipulse/features/medications/presentation/medications_screen.dart';
import 'package:medipulse/features/medications/presentation/refill_screen.dart';
import 'package:medipulse/features/onboarding/presentation/notification_permission_screen.dart';
import 'package:medipulse/features/onboarding/presentation/onboarding_screen.dart';
import 'package:medipulse/features/onboarding/presentation/splash_screen.dart';
import 'package:medipulse/features/profile/presentation/profile_screen.dart';
import 'package:medipulse/features/reports/presentation/reports_screen.dart';
import 'package:medipulse/features/scanner/domain/extraction_models.dart';
import 'package:medipulse/features/scanner/domain/scanner_pipeline.dart';
import 'package:medipulse/features/scanner/presentation/scan_screens.dart';
import 'package:medipulse/features/ai/presentation/ai_chat_screen.dart';
import 'package:medipulse/features/caregivers/presentation/family_caregiver_screen.dart';
import 'package:medipulse/features/settings/presentation/settings_screen.dart';
import 'package:medipulse/features/subscriptions/presentation/paywall_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/boot', builder: (context, state) => const BootScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/permissions',
        builder: (context, state) => const NotificationPermissionScreen(),
      ),
      GoRoute(
        path: '/medications/add',
        builder: (context, state) => AddMedicationScreen(
          scanOutcome: state.extra is ScanOutcome ? state.extra as ScanOutcome : null,
        ),
      ),
      GoRoute(
        path: '/scan/prescription',
        builder: (context, state) => const ScanCaptureScreen(kind: ScanKind.prescription),
      ),
      GoRoute(
        path: '/scan/package',
        builder: (context, state) => const ScanCaptureScreen(kind: ScanKind.package),
      ),
      GoRoute(
        path: '/scan/review',
        builder: (context, state) => ScanReviewScreen(outcome: state.extra! as ScanOutcome),
      ),
      GoRoute(
        path: '/medications/:id/refill',
        builder: (context, state) => RefillScreen(medicationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/medications/:id/edit',
        builder: (context, state) => AddMedicationScreen(existingId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/medications/:id',
        builder: (context, state) => MedicationDetailScreen(
          medicationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/settings/profile', builder: (context, state) => const EditProfileScreen()),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/accessibility',
        builder: (context, state) => const AccessibilitySettingsScreen(),
      ),
      GoRoute(path: '/settings/language', builder: (context, state) => const LanguageSettingsScreen()),
      GoRoute(path: '/settings/subscription', builder: (context, state) => const SubscriptionScreen()),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => PaywallScreen(
          featureName: state.extra is String ? state.extra! as String : 'This feature',
        ),
      ),
      GoRoute(path: '/family', builder: (context, state) => const FamilyCaregiverScreen()),
      GoRoute(path: '/ai', builder: (context, state) => const AiChatScreen()),
      GoRoute(path: '/settings/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const LegalScreen(title: 'Terms', body: LegalCopy.termsPlaceholder),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const LegalScreen(
          title: 'Privacy Policy',
          body: LegalCopy.privacyPlaceholder,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(
            routes: [GoRoute(path: '/medications', builder: (_, _) => const MedicationsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
});
