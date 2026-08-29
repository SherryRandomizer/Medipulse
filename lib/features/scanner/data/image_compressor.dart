import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class ImageCompressor {
  Future<String> compress(String path) async {
    final file = File(path);
    if (!file.existsSync()) return path;
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return path;
    final resized = decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;
    final outPath = p.join(p.dirname(path), 'medipulse_scan.jpg');
    await File(outPath).writeAsBytes(img.encodeJpg(resized, quality: 70));
    return outPath;
  }
}
