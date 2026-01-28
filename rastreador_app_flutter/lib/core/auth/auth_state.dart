import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api_client.dart';
import 'auth_repository.dart';

class AuthState extends ChangeNotifier {
  final AuthRepository _repo;

  String? _token;
  Map<String, dynamic>? _user;
  bool _isBootstrapping = true;

  AuthState(this._repo);

  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty && _user != null;
  bool get isBootstrapping => _isBootstrapping;

  String get role => (_user?['role'] ?? '').toString().toLowerCase();
  int get userId => int.tryParse((_user?['id'] ?? '0').toString()) ?? 0;

  Future<void> bootstrap() async {
    _isBootstrapping = true;
    notifyListeners();

    final restored = await _repo.tryRestoreSession();
    if (restored != null) {
      _token = restored.token;
      _user = restored.user;
    }

    _isBootstrapping = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String senha}) async {
    final res = await _repo.login(email: email, senha: senha);
    _token = res.token;
    _user = res.user;
    notifyListeners();
  }

  Future<void> logout({bool silent = false}) async {
    await _repo.logout();
    _token = null;
    _user = null;
    if (!silent) notifyListeners();
  }

  /// Para o go_router atualizar quando o estado muda.
  Listenable get listenable => this;
}
