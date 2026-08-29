import 'dart:convert';
import 'dart:io';

import 'package:medipulse/core/constants/app_constants.dart';
import 'package:medipulse/core/logging/app_logger.dart';
import 'package:medipulse/core/logging/crash_redaction.dart';
import 'package:uuid/uuid.dart';

abstract class CrashSink {
  Future<void> send(RedactedCrashReport report);
}

class NoOpCrashSink implements CrashSink {
  const NoOpCrashSink();

  @override
  Future<void> send(RedactedCrashReport report) async {}
}

class SentryStoreSink implements CrashSink {
  SentryStoreSink({required this.dsn, HttpClient? client, Uuid? uuid})
    : _client = client ?? HttpClient(),
      _uuid = uuid ?? const Uuid();

  final SentryDsn dsn;
  final HttpClient _client;
  final Uuid _uuid;

  @override
  Future<void> send(RedactedCrashReport report) async {
    final eventId = _uuid.v4().replaceAll('-', '');
    final body = jsonEncode({
      'event_id': eventId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'platform': 'other',
      'release': 'medipulse@${AppConstants.appVersion}',
      'exception': {
        'values': [
          {
            'type': report.errorType,
            'value': '[redacted]',
            'stacktrace': {
              'frames': [
                for (final frame in report.frames) {'filename': frame, 'in_app': true},
              ],
            },
          },
        ],
      },
    });
    final request = await _client.postUrl(Uri.parse(dsn.storeUrl));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(
      'X-Sentry-Auth',
      'Sentry sentry_version=7, sentry_client=medipulse/${AppConstants.appVersion}, sentry_key=${dsn.publicKey}',
    );
    request.add(utf8.encode(body));
    final response = await request.close().timeout(const Duration(seconds: 5));
    await response.drain<void>();
  }
}

class PrivacyCrashReporter {
  PrivacyCrashReporter({
    required CrashSink sink,
    AppLogger logger = const AppLogger(),
  }) : _sink = sink,
       _logger = logger;

  final CrashSink _sink;
  final AppLogger _logger;

  Future<void> record(Object error, StackTrace stack, {bool fatal = false}) async {
    final report = CrashRedaction.from(error, stack, fatal: fatal);
    try {
      await _sink.send(report);
    } on Object {
      _logger.error('Crash report could not be sent');
    }
  }
}
