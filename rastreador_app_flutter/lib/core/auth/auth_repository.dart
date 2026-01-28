import 'dart:convert';

import 'package:jwt_decoder/jwt_decoder.dart';

import '../api_client.dart';
import 'auth_storage.dart';

class AuthRepository {
  final ApiClient _api;
  final AuthStorage _storage;

  AuthRepository(this._api, this._storage);

  Future<({String token, Map<String, dynamic> user})> login(
      {required String email, required String senha}) async {
    final data = await _api.postJson('/login', body: {'email': email, 'senha': senha});

    final token = (data['token'] ?? '').toString();
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    if (token.isEmpty || user.isEmpty) {
      throw ApiException('Resposta de login inválida.');
    }

    await _storage.saveToken(token);
    await _storage.saveUserJson(jsonEncode(user));

    return (token: token, user: user);
  }

  Future<({String token, Map<String, dynamic> user})?> tryRestoreSession() async {
    final token = await _storage.readToken();
    final userJson = await _storage.readUserJson();

    if (token == null || token.isEmpty || userJson == null || userJson.isEmpty) {
      return null;
    }

    // se expirou, não restaura
    try {
      if (JwtDecoder.isExpired(token)) {
        await _storage.clear();
        return null;
      }
    } catch (_) {
      await _storage.clear();
      return null;
    }

    final user = (jsonDecode(userJson) as Map).cast<String, dynamic>();
    return (token: token, user: user);
  }

  Future<void> logout() => _storage.clear();
}
