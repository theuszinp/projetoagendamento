import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStorage {
  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> saveUserJson(String json);

  Future<String?> readUserJson();

  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user_json';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<String?> readUserJson() => _storage.read(key: _userKey);

  @override
  Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<void> saveUserJson(String json) {
    return _storage.write(key: _userKey, value: json);
  }
}

class MemorySessionStorage implements SessionStorage {
  final Map<String, String> _memory = <String, String>{};

  @override
  Future<void> clear() async {
    _memory.clear();
  }

  @override
  Future<String?> readToken() async => _memory['token'];

  @override
  Future<String?> readUserJson() async => _memory['user'];

  @override
  Future<void> saveToken(String token) async {
    _memory['token'] = token;
  }

  @override
  Future<void> saveUserJson(String json) async {
    _memory['user'] = json;
  }
}
