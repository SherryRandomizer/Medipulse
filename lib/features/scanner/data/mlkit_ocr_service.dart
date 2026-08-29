import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class MlKitOcrService implements OCRService {
  @override
  bool get isConfigured => true;

  @override
  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer();
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      final text = result.text.trim();
      if (text.isEmpty) {
        throw const AiFailure(
          'We could not read any text in that photo. Try better light, or type what you see.',
        );
      }
      return text;
    } catch (error) {
      if (error is AiFailure) rethrow;
      throw const AiFailure(
        'We could not read that image on this device. You can type the label text instead.',
      );
    } finally {
      await recognizer.close();
    }
  }
}
