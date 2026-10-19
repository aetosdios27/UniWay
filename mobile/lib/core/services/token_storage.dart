import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TokenStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

class SecureTokenStorage implements TokenStorage {
  static const String _key = 'uniway_auth_token';

  final FlutterSecureStorage _storage;

  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class SharedPreferencesTokenStorage implements TokenStorage {
  static const String _key = 'uniway_auth_token';

  final SharedPreferences _prefs;

  SharedPreferencesTokenStorage(this._prefs);

  @override
  Future<String?> read() async => _prefs.getString(_key);

  @override
  Future<void> write(String token) => _prefs.setString(_key, token);

  @override
  Future<void> delete() => _prefs.remove(_key);
}
