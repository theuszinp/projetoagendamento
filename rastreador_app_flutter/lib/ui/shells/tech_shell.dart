import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../TechDashboardScreen.dart';

class TechShell extends StatefulWidget {
  const TechShell({super.key});

  @override
  State<TechShell> createState() => _TechShellState();
}

class _TechShellState extends State<TechShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    final pages = <Widget>[
      TechDashboardScreen(authToken: auth.token ?? '', techId: auth.userId),
      const _TechHistoryPlaceholder(),
      const _TechProfilePlaceholder(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'Fila'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _TechHistoryPlaceholder extends StatelessWidget {
  const _TechHistoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Histórico (em evolução)'));
  }
}

class _TechProfilePlaceholder extends StatelessWidget {
  const _TechProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Perfil (em evolução)'));
  }
}
