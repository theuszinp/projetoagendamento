import '../core/network/api_client.dart';
import '../core/session/app_session_controller.dart';
import '../core/session/session_storage.dart';
import '../features/scheduling/data/schedule_repository.dart';
import '../features/users/data/auth_repository.dart';
import '../features/users/data/user_repository.dart';

class AppDependencies {
  AppDependencies._(SessionStorage storage)
      : sessionController = AppSessionController(),
        sessionStorage = storage {
    apiClient = ApiClient(
      tokenProvider: () => sessionController.token,
      onUnauthorized: () => sessionController.logout(silent: true),
    );
    authRepository = AuthRepository(apiClient, sessionStorage);
    userRepository = UserRepository(apiClient);
    scheduleRepository = ScheduleRepository(apiClient);

    sessionController.attachRepository(authRepository);
  }

  factory AppDependencies.production() {
    return AppDependencies._(SecureSessionStorage());
  }

  factory AppDependencies.testing() {
    return AppDependencies._(MemorySessionStorage());
  }

  final AppSessionController sessionController;
  final SessionStorage sessionStorage;

  late final ApiClient apiClient;
  late final AuthRepository authRepository;
  late final UserRepository userRepository;
  late final ScheduleRepository scheduleRepository;

  void initialize() {
    sessionController.bootstrap();
  }
}
