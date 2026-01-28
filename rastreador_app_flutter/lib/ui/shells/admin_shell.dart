import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../admindashboardscreen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    final pages = <Widget>[
      AdminDashboardScreen(authToken: auth.token ?? '', userId: auth.userId),
      const _AdminReportsPlaceholder(),
      const _AdminSettingsPlaceholder(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Painel'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Relatórios'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}

class _AdminReportsPlaceholder extends StatelessWidget {
  const _AdminReportsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Relatórios (em evolução)'));
  }
}

class _AdminSettingsPlaceholder extends StatelessWidget {
  const _AdminSettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Configurações (em evolução)'));
  }
}
