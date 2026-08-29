sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'You appear to be offline. Try again when you have a connection.']);
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.message = 'That took too long. Please try again.']);
}

class AuthFailure extends AppFailure {
  const AuthFailure([super.message = 'We could not sign you in. Check your email and password.']);
}

class PermissionFailure extends AppFailure {
  const PermissionFailure([super.message = 'MediPulse needs a permission to continue.']);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure([super.message = 'Please check the highlighted fields.']);
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'We could not find that item.']);
}

class ConfigurationFailure extends AppFailure {
  const ConfigurationFailure(super.message);
}

class StorageFailure extends AppFailure {
  const StorageFailure([super.message = 'Something went wrong saving your information. Please try again.']);
}

class NotificationFailure extends AppFailure {
  const NotificationFailure([
    super.message =
        'Reminders could not be scheduled. Check notification settings and battery optimization.',
  ]);
}

class SubscriptionFailure extends AppFailure {
  const SubscriptionFailure([super.message = 'This feature is part of MediPulse Premium.']);
}

class AiFailure extends AppFailure {
  const AiFailure([
    super.message = 'We could not process that image. You can enter the medication manually.',
  ]);
}
