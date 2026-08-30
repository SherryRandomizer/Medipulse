class AuthValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool looksLikeEmail(String value) => _email.hasMatch(value.trim().toLowerCase());

  static String? passwordIssue(String password) {
    if (password.length < 8) {
      return 'Use a password with at least 8 characters.';
    }
    return null;
  }
}
