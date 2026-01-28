import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../create_ticket_screen.dart';
import '../../SellerTicketListScreen.dart';

class SellerShell extends StatefulWidget {
  const SellerShell({super.key});

  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    final pages = <Widget>[
      CreateTicketScreen(
        authToken: auth.token ?? '',
        requestedByUserId: auth.userId,
      ),
      SellerTicketListScreen(
        authToken: auth.token ?? '',
        requestedByUserId: auth.userId,
      ),
      const _ClientsPlaceholder(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Novo'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Meus tickets'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
        ],
      ),
    );
  }
}

class _ClientsPlaceholder extends StatelessWidget {
  const _ClientsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Clientes (em evolução)'));
  }
}
