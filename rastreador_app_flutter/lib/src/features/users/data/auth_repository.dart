import 'dart:convert';

import 'package:jwt_decoder/jwt_decoder.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_storage.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final AppUser user;
}

class AuthRepository {
  AuthRepository(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final SessionStorage _storage;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/login',
      body: <String, dynamic>{
        'email': email,
        'senha': password,
      },
    );

    final token = (response['token'] ?? '').toString();
    final userMap = (response['user'] as Map?)?.cast<String, dynamic>();

    if (token.isEmpty || userMap == null) {
      throw ApiException('Resposta de login inválida.');
    }

    final user = AppUser.fromJson(userMap);

    await _storage.saveToken(token);
    await _storage.saveUserJson(jsonEncode(user.toJson()));

    return AuthSession(token: token, user: user);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await _apiClient.postJson(
      '/users',
      body: <String, dynamic>{
        'name': name,
        'email': email,
        'senha': password,
        'role': role.apiValue,
      },
    );
  }

  Future<AuthSession?> tryRestoreSession() async {
    final token = await _storage.readToken();
    final userJson = await _storage.readUserJson();

    if (token == null || token.isEmpty || userJson == null || userJson.isEmpty) {
      return null;
    }

    try {
      if (JwtDecoder.isExpired(token)) {
        await _storage.clear();
        return null;
      }

      final userMap = (jsonDecode(userJson) as Map).cast<String, dynamic>();
      return AuthSession(
        token: token,
        user: AppUser.fromJson(userMap),
      );
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() {
    return _storage.clear();
  }
}
