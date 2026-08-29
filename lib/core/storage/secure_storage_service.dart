import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class SecureStorageService implements StorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> writeSecure(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<String?> readSecure(String key) => _storage.read(key: key);

  @override
  Future<void> deleteSecure(String key) => _storage.delete(key: key);
}
