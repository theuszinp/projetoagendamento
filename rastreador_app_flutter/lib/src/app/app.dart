import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/app_session_controller.dart';
import '../features/address/data/via_cep_repository.dart';
import '../features/reports/data/report_repository.dart';
import '../features/scheduling/data/schedule_repository.dart';
import '../features/users/data/auth_repository.dart';
import '../features/users/data/user_repository.dart';
import 'app_dependencies.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    required this.dependencies,
  }) : _router = createRouter(dependencies.sessionController);

  final AppDependencies dependencies;
  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: dependencies.apiClient),
        Provider<AuthRepository>.value(value: dependencies.authRepository),
        Provider<UserRepository>.value(value: dependencies.userRepository),
        Provider<ViaCepRepository>.value(value: dependencies.viaCepRepository),
        Provider<ReportRepository>.value(value: dependencies.reportRepository),
        Provider<ScheduleRepository>.value(value: dependencies.scheduleRepository),
        ChangeNotifierProvider<AppSessionController>.value(
          value: dependencies.sessionController,
        ),
      ],
      child: MaterialApp.router(
        title: 'Agenda de Instalações',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
      ),
    );
  }
}
