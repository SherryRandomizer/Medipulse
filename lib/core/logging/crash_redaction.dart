class SentryDsn {
  const SentryDsn({
    required this.scheme,
    required this.host,
    required this.publicKey,
    required this.projectId,
  });

  final String scheme;
  final String host;
  final String publicKey;
  final String projectId;

  static SentryDsn? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isEmpty) return null;
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return SentryDsn(
      scheme: uri.scheme.isEmpty ? 'https' : uri.scheme,
      host: uri.host,
      publicKey: uri.userInfo.split(':').first,
      projectId: segments.last,
    );
  }

  String get storeUrl => '$scheme://$host/api/$projectId/store/';
}

class RedactedCrashReport {
  const RedactedCrashReport({
    required this.errorType,
    required this.frames,
    required this.fatal,
  });

  final String errorType;
  final List<String> frames;
  final bool fatal;
}

class CrashRedaction {
  static final _quoted = RegExp(r"""['"][^'"]*['"]""");

  static RedactedCrashReport from(Object error, StackTrace stack, {required bool fatal}) {
    return RedactedCrashReport(
      errorType: error.runtimeType.toString(),
      frames: _frames(stack),
      fatal: fatal,
    );
  }

  static List<String> _frames(StackTrace stack) {
    return stack
        .toString()
        .split('\n')
        .where((line) => line.contains('package:medipulse'))
        .map((line) => line.replaceAll(_quoted, "'***'"))
        .take(20)
        .toList();
  }
}
