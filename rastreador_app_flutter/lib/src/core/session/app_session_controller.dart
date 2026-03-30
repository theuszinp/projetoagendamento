import 'package:flutter/foundation.dart';

import '../../features/users/data/auth_repository.dart';
import '../../features/users/domain/app_user.dart';
import '../../features/users/domain/user_role.dart';

class AppSessionController extends ChangeNotifier {
  AuthRepository? _repository;
  String? _token;
  AppUser? _currentUser;
  bool _isBootstrapping = true;

  String? get token => _token;
  AppUser? get currentUser => _currentUser;
  UserRole get role => _currentUser?.role ?? UserRole.unknown;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isBootstrapping => _isBootstrapping;
  int get currentUserId => _currentUser?.id ?? 0;

  void attachRepository(AuthRepository repository) {
    _repository = repository;
  }

  Future<void> bootstrap() async {
    _isBootstrapping = true;
    notifyListeners();

    final restored = await _repository?.tryRestoreSession();
    if (restored != null) {
      _token = restored.token;
      _currentUser = restored.user;
    }

    _isBootstrapping = false;
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('AuthRepository não configurado.');
    }

    final session = await repository.login(email: email, password: password);
    _token = session.token;
    _currentUser = session.user;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('AuthRepository não configurado.');
    }

    await repository.register(
      name: name,
      email: email,
      password: password,
      role: role,
    );
  }

  Future<void> logout({bool silent = false}) async {
    await _repository?.logout();
    _token = null;
    _currentUser = null;

    if (!silent) {
      notifyListeners();
      return;
    }

    notifyListeners();
  }
}
