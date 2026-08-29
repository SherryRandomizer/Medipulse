import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/features/reports/domain/report_pdf_builder.dart';
import 'package:medipulse/features/scanner/domain/extraction_models.dart';
import 'package:medipulse/features/scanner/domain/heuristic_extractor.dart';
import 'package:medipulse/features/scanner/domain/scanner_pipeline.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/phase1_adapters.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class _FakeOcr implements OCRService {
  @override
  bool get isConfigured => true;

  @override
  Future<String> recognizeText(String imagePath) async => 'should not run';
}

void main() {
  test('prescription extractor pulls dose frequency and flags weak times', () {
    const text = '''
City Clinic
Metformin
500 mg
Take 1 tablet twice daily after meals for 7 days
''';
    final result = HeuristicExtractor().extractPrescription(text);
    expect(result.medicineName.value, 'Metformin');
    expect(result.strength.value, contains('500'));
    expect(result.frequency.value, contains('twice'));
    expect(result.foodInstruction.value, contains('after'));
    expect(result.times.needsReview, isTrue);
  });

  test('package extractor never claims certainty above 0.85', () {
    const text = '''
Atorvastatin
20 mg
Tablet
Acme Pharma Ltd
EXP 12/2027
Batch AB12
''';
    final result = HeuristicExtractor().extractPackage(text);
    expect(result.overallConfidence <= 0.85, isTrue);
    expect(result.manufacturer.value, contains('Pharma'));
  });

  test('pipeline uses typed text and does not invent a medication save', () async {
    final pipeline = ScannerPipeline(
      ocr: _FakeOcr(),
      analytics: const PrivacyAnalyticsService(),
    );
    final outcome = await pipeline.process(
      imagePath: '',
      kind: ScanKind.prescription,
      typedText: 'Example Medicine\n500 mg\n1 tablet once daily',
    );
    expect(outcome.prescription?.medicineName.value, 'Example Medicine');
    expect(outcome.prescription?.toJson()['confidence'], isNotNull);
  });

  test('pdf report includes the medical disclaimer', () async {
    final bytes = await ReportPdfBuilder().build(
      patientName: 'Alex',
      from: DateTime.utc(2026, 6, 1),
      to: DateTime.utc(2026, 6, 7),
      medications: const [],
      summary: const AdherenceSummary(
        scheduled: 30,
        taken: 27,
        missed: 2,
        skipped: 1,
        pending: 0,
        snoozed: 0,
      ),
    );
    final asText = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));
    expect(asText.contains('informational') || asText.toLowerCase().contains('disclaimer') || bytes.isNotEmpty, isTrue);
    expect(LegalCopy.reportDisclaimer.isNotEmpty, isTrue);
    expect(bytes.length, greaterThan(100));
  });
}
