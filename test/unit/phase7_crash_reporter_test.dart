import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/core/logging/crash_redaction.dart';
import 'package:medipulse/core/logging/crash_reporter.dart';

class _MemorySink implements CrashSink {
  RedactedCrashReport? last;

  @override
  Future<void> send(RedactedCrashReport report) async {
    last = report;
  }
}

void main() {
  test('sentry DSN parse builds store URL and rejects empty', () {
    expect(SentryDsn.tryParse(''), isNull);
    final dsn = SentryDsn.tryParse('https://abc123@o1.ingest.sentry.io/99');
    expect(dsn, isNotNull);
    expect(dsn!.publicKey, 'abc123');
    expect(dsn.projectId, '99');
    expect(dsn.storeUrl, 'https://o1.ingest.sentry.io/api/99/store/');
  });

  test('crash redaction keeps type and medipulse frames without quoted medicine names', () {
    final stack = StackTrace.fromString(
      "#0 actOnDose (package:medipulse/features/medications/domain/medication_coordinator.dart:1:1) 'Metformin'\n"
      '#1 <asynchronous suspension>\n',
    );
    final report = CrashRedaction.from(StateError("Dose of 'Metformin' failed"), stack, fatal: true);
    expect(report.errorType, 'StateError');
    expect(report.fatal, isTrue);
    expect(report.frames, isNotEmpty);
    expect(report.frames.join(' ').contains('Metformin'), isFalse);
    expect(report.frames.join(' ').contains("***"), isTrue);
  });

  test('privacy reporter sends redacted payload through the sink', () async {
    final sink = _MemorySink();
    final reporter = PrivacyCrashReporter(sink: sink);
    await reporter.record(StateError('hidden'), StackTrace.current);
    expect(sink.last?.errorType, 'StateError');
    expect(sink.last?.fatal, isFalse);
  });
}
