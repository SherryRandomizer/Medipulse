import 'package:medipulse/features/scanner/domain/heuristic_extractor.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class HeuristicAiService implements AIService {
  HeuristicAiService({HeuristicExtractor? extractor}) : _extractor = extractor ?? HeuristicExtractor();

  final HeuristicExtractor _extractor;

  @override
  bool get isConfigured => true;

  @override
  Future<Map<String, dynamic>> extractPrescription(String imagePath) async {
    throw UnsupportedError('Pass OCR text through ScannerPipeline; images are not sent to a cloud AI in this build.');
  }

  @override
  Future<Map<String, dynamic>> extractPackage(String imagePath) async {
    throw UnsupportedError('Pass OCR text through ScannerPipeline; images are not sent to a cloud AI in this build.');
  }

  @override
  Future<String> answerScheduleQuestion({
    required String question,
    required String scheduleContext,
  }) async {
    return 'MediPulse AI is not enabled in this build. Your saved schedule is shown in Home and Calendar. For medical advice, talk with a healthcare professional.';
  }

  Map<String, dynamic> prescriptionFromText(String text) => _extractor.extractPrescription(text).toJson();
}
