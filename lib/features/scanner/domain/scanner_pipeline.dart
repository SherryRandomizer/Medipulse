import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/features/scanner/data/image_compressor.dart';
import 'package:medipulse/features/scanner/domain/extraction_models.dart';
import 'package:medipulse/features/scanner/domain/heuristic_extractor.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class ScanOutcome {
  const ScanOutcome({
    required this.kind,
    required this.imagePath,
    required this.ocrText,
    this.prescription,
    this.package,
  });

  final ScanKind kind;
  final String imagePath;
  final String ocrText;
  final PrescriptionExtraction? prescription;
  final PackageExtraction? package;
}

class ScannerPipeline {
  ScannerPipeline({
    required OCRService ocr,
    required AnalyticsService analytics,
    ImageCompressor? compressor,
    HeuristicExtractor? extractor,
  }) : _ocr = ocr,
       _analytics = analytics,
       _compressor = compressor ?? ImageCompressor(),
       _extractor = extractor ?? HeuristicExtractor();

  final OCRService _ocr;
  final AnalyticsService _analytics;
  final ImageCompressor _compressor;
  final HeuristicExtractor _extractor;

  Future<ScanOutcome> process({
    required String imagePath,
    required ScanKind kind,
    String? typedText,
  }) async {
    await _analytics.logEvent('prescription_scan_started');
    var text = typedText?.trim() ?? '';
    var compressed = imagePath;
    if (text.isEmpty) {
      if (imagePath.isEmpty) {
        throw const ValidationFailure('Take a photo or type the text from the label.');
      }
      compressed = await _compressor.compress(imagePath);
      try {
        text = await _ocr.recognizeText(compressed);
      } on AiFailure {
        rethrow;
      } catch (_) {
        throw const AiFailure(
          'We could not read that image. You can type what you see on the label.',
        );
      }
    }
    if (kind == ScanKind.prescription) {
      final extraction = _extractor.extractPrescription(text);
      await _analytics.logEvent('prescription_scan_completed');
      return ScanOutcome(
        kind: kind,
        imagePath: compressed,
        ocrText: text,
        prescription: extraction,
      );
    }
    final extraction = _extractor.extractPackage(text);
    await _analytics.logEvent('prescription_scan_completed');
    return ScanOutcome(
      kind: kind,
      imagePath: compressed,
      ocrText: text,
      package: extraction,
    );
  }
}
