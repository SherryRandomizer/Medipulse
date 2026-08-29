import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const iterations = 12000;

  ({String hash, String salt}) hashPassword(String password, {String? salt}) {
    final usedSalt = salt ?? DateTime.now().microsecondsSinceEpoch.toString();
    var digest = Uint8List.fromList(utf8.encode('$usedSalt::$password'));
    for (var i = 0; i < iterations; i++) {
      digest = Uint8List.fromList(sha256.convert(digest).bytes);
    }
    return (hash: sha256.convert(digest).toString(), salt: usedSalt);
  }

  bool verify(String password, String hash, String salt) {
    return hashPassword(password, salt: salt).hash == hash;
  }
}
