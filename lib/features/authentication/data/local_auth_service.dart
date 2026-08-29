import 'package:clock/clock.dart';
import 'package:medipulse/core/config/app_config.dart';
import 'package:medipulse/core/constants/app_constants.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/core/security/password_hasher.dart';
import 'package:medipulse/core/storage/local_database.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';
import 'package:uuid/uuid.dart';

class LocalAuthService implements AuthService {
  LocalAuthService({
    required LocalDatabase database,
    required StorageService storage,
    required AppConfig config,
    PasswordHasher? hasher,
    Uuid? uuid,
  }) : _db = database,
       _storage = storage,
       _config = config,
       _hasher = hasher ?? PasswordHasher(),
       _uuid = uuid ?? const Uuid();

  static const _sessionKey = 'session_user_id';

  final LocalDatabase _db;
  final StorageService _storage;
  final AppConfig _config;
  final PasswordHasher _hasher;
  final Uuid _uuid;

  @override
  Stream<UserProfile?> authState() async* {
    yield await currentUser();
  }

  @override
  Future<UserProfile?> currentUser() async {
    final id = await _storage.readSecure(_sessionKey);
    if (id == null) return null;
    return _db.userById(id);
  }

  @override
  Future<UserProfile> signInWithEmail({required String email, required String password}) async {
    final row = await _db.userAuthRow(email.trim().toLowerCase());
    if (row == null) {
      throw const AuthFailure('No account found for that email.');
    }
    final hash = row['password_hash'] as String?;
    final salt = row['password_salt'] as String?;
    if (hash == null || salt == null || !_hasher.verify(password, hash, salt)) {
      throw const AuthFailure();
    }
    final user = await _db.userById(row['id']! as String);
    if (user == null) throw const AuthFailure();
    await _storage.writeSecure(_sessionKey, user.id);
    return user;
  }

  @override
  Future<UserProfile> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!_looksLikeEmail(normalized)) {
      throw const ValidationFailure('Enter a valid email address.');
    }
    if (password.length < 8) {
      throw const ValidationFailure('Use a password with at least 8 characters.');
    }
    if (await _db.userAuthRow(normalized) != null) {
      throw const AuthFailure('An account with that email already exists.');
    }
    final now = clock.now().toUtc();
    final hashed = _hasher.hashPassword(password);
    final user = UserProfile(
      id: _uuid.v4(),
      email: normalized,
      displayName: displayName.trim(),
      timeZone: 'UTC',
      preferredLanguage: 'en',
      emailVerified: false,
      isGuest: false,
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertUser(user, passwordHash: hashed.hash, passwordSalt: hashed.salt);
    await _db.upsertNotificationPreference(
      NotificationPreference(
        userId: user.id,
        enabled: true,
        soundEnabled: true,
        vibrationEnabled: true,
        snoozeMinutes: AppConstants.defaultSnoozeMinutes,
        updatedAt: now,
      ),
    );
    await _storage.writeSecure(_sessionKey, user.id);
    return user;
  }

  @override
  Future<UserProfile> continueAsGuest({required String timeZone}) async {
    final existing = await currentUser();
    if (existing != null) return existing;
    final now = clock.now().toUtc();
    final user = UserProfile(
      id: _uuid.v4(),
      email: '',
      displayName: '',
      timeZone: timeZone,
      preferredLanguage: 'en',
      emailVerified: false,
      isGuest: true,
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertUser(user);
    await _db.upsertNotificationPreference(
      NotificationPreference(
        userId: user.id,
        enabled: true,
        soundEnabled: true,
        vibrationEnabled: true,
        snoozeMinutes: AppConstants.defaultSnoozeMinutes,
        updatedAt: now,
      ),
    );
    await _storage.writeSecure(_sessionKey, user.id);
    return user;
  }

  @override
  Future<void> signOut() => _storage.deleteSecure(_sessionKey);

  @override
  Future<void> requestPasswordReset(String email) async {
    if (_config.cloudAuthAvailable) {
      throw const ConfigurationFailure(
        'Password reset email will be sent when cloud authentication is enabled.',
      );
    }
    throw const ConfigurationFailure(
      'Password reset by email needs cloud authentication. Until that is configured, you can delete local data from Settings or reinstall the app.',
    );
  }

  @override
  Future<void> sendEmailVerification() async {
    throw const ConfigurationFailure(
      'Verification emails are sent after Firebase Authentication is configured for this build.',
    );
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    if (!_config.googleSignInConfigured) {
      throw const ConfigurationFailure(
        'Google Sign-In is not configured for this build. Use email or continue without an account.',
      );
    }
    throw const ConfigurationFailure('Google Sign-In adapter is not wired in this build.');
  }

  @override
  Future<UserProfile> signInWithApple() async {
    throw const ConfigurationFailure(
      'Apple Sign-In is available on iOS after Apple and Firebase credentials are configured.',
    );
  }

  @override
  Future<void> deleteAccount() async {
    final user = await currentUser();
    if (user == null) return;
    await _db.deleteUserCascade(user.id);
    await _storage.deleteSecure(_sessionKey);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await _db.upsertUser(profile.copyWith(updatedAt: clock.now().toUtc()));
    return (await _db.userById(profile.id))!;
  }

  bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}
