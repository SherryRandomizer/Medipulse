import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/notifications/local_notification_service.dart';
import 'package:medipulse/core/notifications/pending_dose_action_store.dart';
import 'package:medipulse/shared/models/entities.dart';

Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }

  final container = ProviderContainer();
  final notifications = container.read(notificationServiceProvider);
  await notifications.initialize();
  if (notifications is LocalNotificationService) {
    notifications.onAction = (action, doseId) async {
      await _applyDoseAction(container, action, doseId);
    };
  }
  await _applyPendingDoseActions(container);

  await container.read(analyticsServiceProvider).logEvent('app_open');
  final user = await container.read(authServiceProvider).currentUser();
  if (user != null) {
    await container.read(medicationCoordinatorProvider).markOverdueMissed(
      user.id,
      firstName: user.greetingName,
    );
    await container.read(medicationCoordinatorProvider).rescheduleNotifications(user.id);
  }
  return container;
}

Future<String> resolveStartLocation(ProviderContainer container) async {
  final onboarding = await container.read(onboardingCompleteProvider.future);
  if (!onboarding) return '/onboarding';
  final user = await container.read(authServiceProvider).currentUser();
  if (user == null) return '/auth';
  final prompted = await container.read(notificationPromptedProvider.future);
  if (!prompted) return '/permissions';
  return '/home';
}

Future<void> _applyPendingDoseActions(ProviderContainer container) async {
  final pending = await PendingDoseActionStore().take();
  if (pending == null) return;
  await _applyDoseAction(container, pending.actionId, pending.doseId);
}

Future<void> _applyDoseAction(ProviderContainer container, String action, String doseId) async {
  final dose = await container.read(doseRepositoryProvider).getById(doseId);
  if (dose == null) return;
  final mapped = switch (action) {
    LocalNotificationService.takenAction => DoseStatus.taken,
    LocalNotificationService.skipAction => DoseStatus.skipped,
    LocalNotificationService.snoozeAction => DoseStatus.snoozed,
    _ => null,
  };
  if (mapped == null) return;
  await container.read(medicationCoordinatorProvider).actOnDose(dose, mapped);
}

void goToStart(BuildContext context, String location) {
  context.go(location);
}
