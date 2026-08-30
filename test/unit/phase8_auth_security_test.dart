import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/core/security/password_hasher.dart';
import 'package:medipulse/features/authentication/domain/auth_validators.dart';

void main() {
  test('password hasher verifies the same password and rejects another', () {
    final hasher = PasswordHasher();
    final stored = hasher.hashPassword('correct-horse', salt: 'fixed-salt');
    expect(hasher.verify('correct-horse', stored.hash, stored.salt), isTrue);
    expect(hasher.verify('wrong-password', stored.hash, stored.salt), isFalse);
    expect(stored.hash.contains('correct-horse'), isFalse);
  });

  test('auth validators require a real email and eight-character password', () {
    expect(AuthValidators.looksLikeEmail('person@example.com'), isTrue);
    expect(AuthValidators.looksLikeEmail('not-an-email'), isFalse);
    expect(AuthValidators.passwordIssue('short'), isNotNull);
    expect(AuthValidators.passwordIssue('long-enough'), isNull);
  });
}
