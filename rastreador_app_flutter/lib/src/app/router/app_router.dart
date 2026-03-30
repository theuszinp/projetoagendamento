import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/app_session_controller.dart';
import '../../features/scheduling/domain/installation_schedule.dart';
import '../../features/scheduling/presentation/screens/admin_dashboard_screen.dart';
import '../../features/scheduling/presentation/screens/admin_schedule_board_screen.dart';
import '../../features/scheduling/presentation/screens/new_schedule_screen.dart';
import '../../features/scheduling/presentation/screens/schedule_details_screen.dart';
import '../../features/scheduling/presentation/screens/seller_dashboard_screen.dart';
import '../../features/scheduling/presentation/screens/seller_schedule_list_screen.dart';
import '../../features/scheduling/presentation/screens/technician_dashboard_screen.dart';
import '../../features/scheduling/presentation/screens/technician_job_details_screen.dart';
import '../../features/scheduling/presentation/screens/technician_agenda_screen.dart';
import '../../features/shared/presentation/splash_screen.dart';
import '../../features/users/domain/user_role.dart';
import '../../features/users/presentation/account_screen.dart';
import '../../features/users/presentation/login_screen.dart';
import '../../features/users/presentation/register_screen.dart';
import '../../features/users/presentation/user_management_screen.dart';
import 'app_routes.dart';

GoRouter createRouter(AppSessionController session) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    redirect: (context, state) {
      final location = state.uri.toString();
      final onPublicRoute = location == AppRoutes.login || location == AppRoutes.register;
      final onSplash = location == AppRoutes.splash;

      if (session.isBootstrapping) {
        return onSplash ? null : AppRoutes.splash;
      }

      if (!session.isAuthenticated) {
        return onPublicRoute ? null : AppRoutes.login;
      }

      if (onSplash || onPublicRoute) {
        return _homeForRole(session.role);
      }

      if (location.startsWith('/seller') && session.role != UserRole.seller) {
        return _homeForRole(session.role);
      }

      if (location.startsWith('/admin') && session.role != UserRole.admin) {
        return _homeForRole(session.role);
      }

      if (location.startsWith('/technician') &&
          session.role != UserRole.technician) {
        return _homeForRole(session.role);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerHome,
        builder: (context, state) => const RoleShellScaffold.seller(),
      ),
      GoRoute(
        path: '/seller/schedules/:id',
        builder: (context, state) {
          final schedule = state.extra as InstallationSchedule?;
          return ScheduleDetailsScreen(
            schedule: schedule,
            scheduleId: int.tryParse(state.pathParameters['id'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        builder: (context, state) => const RoleShellScaffold.admin(),
      ),
      GoRoute(
        path: '/admin/schedules/:id',
        builder: (context, state) {
          final schedule = state.extra as InstallationSchedule?;
          return ScheduleDetailsScreen(
            schedule: schedule,
            scheduleId: int.tryParse(state.pathParameters['id'] ?? ''),
            allowAdminNotes: true,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.technicianHome,
        builder: (context, state) => const RoleShellScaffold.technician(),
      ),
      GoRoute(
        path: '/technician/jobs/:id',
        builder: (context, state) {
          final schedule = state.extra as InstallationSchedule?;
          return TechnicianJobDetailsScreen(
            schedule: schedule,
            scheduleId: int.tryParse(state.pathParameters['id'] ?? ''),
          );
        },
      ),
    ],
  );
}

String _homeForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return AppRoutes.adminHome;
    case UserRole.technician:
      return AppRoutes.technicianHome;
    case UserRole.seller:
      return AppRoutes.sellerHome;
    case UserRole.unknown:
      return AppRoutes.login;
  }
}

class RoleShellScaffold extends StatefulWidget {
  const RoleShellScaffold.admin({super.key}) : role = UserRole.admin;

  const RoleShellScaffold.seller({super.key}) : role = UserRole.seller;

  const RoleShellScaffold.technician({super.key})
      : role = UserRole.technician;

  final UserRole role;

  @override
  State<RoleShellScaffold> createState() => _RoleShellScaffoldState();
}

class _RoleShellScaffoldState extends State<RoleShellScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final config = _buildConfig(widget.role);

    return Scaffold(
      body: SafeArea(child: config.pages[_currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: config.destinations,
      ),
    );
  }

  ({List<Widget> pages, List<NavigationDestination> destinations}) _buildConfig(
    UserRole role,
  ) {
    switch (role) {
      case UserRole.admin:
        return (
          pages: const [
            AdminDashboardScreen(),
            AdminScheduleBoardScreen(),
            UserManagementScreen(),
            AccountScreen(),
          ],
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts),
              label: 'Usuários',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Conta',
            ),
          ],
        );
      case UserRole.technician:
        return (
          pages: const [
            TechnicianDashboardScreen(),
            TechnicianAgendaScreen(),
            AccountScreen(),
          ],
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Hoje',
            ),
            NavigationDestination(
              icon: Icon(Icons.build_circle_outlined),
              selectedIcon: Icon(Icons.build_circle),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Conta',
            ),
          ],
        );
      case UserRole.seller:
        return (
          pages: const [
            SellerDashboardScreen(),
            NewScheduleScreen(),
            SellerScheduleListScreen(),
            AccountScreen(),
          ],
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Novo',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Agendamentos',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Conta',
            ),
          ],
        );
      case UserRole.unknown:
        return (
          pages: const [SizedBox.shrink()],
          destinations: const [
            NavigationDestination(icon: Icon(Icons.block), label: 'Indisponível'),
          ],
        );
    }
  }
}
