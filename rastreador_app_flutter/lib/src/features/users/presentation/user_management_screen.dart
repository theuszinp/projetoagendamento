import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/session_app_bar_actions.dart';
import '../data/user_repository.dart';
import '../domain/app_user.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<_UserManagementData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_UserManagementData> _load() async {
    final repository = context.read<UserRepository>();

    List<AppUser> pending = const [];
    String? warning;

    try {
      pending = await repository.fetchPendingUsers();
    } on ApiException catch (error) {
      warning = error.message;
    }

    final users = await repository.fetchAllUsers();

    return _UserManagementData(
      pendingUsers: pending,
      activeUsers: users,
      warningMessage: warning,
    );
  }

  Future<void> _approve(UserRepository repository, int userId) async {
    try {
      await repository.approveUser(userId);
      setState(() => _future = _load());
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário aprovado com sucesso.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<UserRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários e permissões'),
        actions: [
          SessionAppBarActions(
            onRefresh: () async => setState(() => _future = _load()),
          ),
        ],
      ),
      body: FutureBuilder<_UserManagementData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Carregando usuários...');
          }

          if (snapshot.hasError) {
            return EmptyState(
              title: 'Erro ao carregar usuários',
              message: resolveErrorMessage(snapshot.error!),
              icon: Icons.error_outline,
            );
          }

          final data = snapshot.data ??
              const _UserManagementData(
                pendingUsers: [],
                activeUsers: [],
              );

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SectionHeader(
                  title: 'RBAC e aprovação',
                  subtitle:
                      'Admin visualiza tudo, vendedor enxerga apenas o próprio pipeline e instalador somente os serviços atribuídos.',
                ),
                const SizedBox(height: 20),
                if ((data.warningMessage ?? '').isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Atenção: ${data.warningMessage}. O restante da tela continua funcionando.',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cadastros pendentes',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (data.pendingUsers.isEmpty)
                          const Text('Nenhum usuário aguardando aprovação.')
                        else
                          ...data.pendingUsers.map(
                            (user) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(user.name),
                              subtitle: Text('${user.email} • ${user.role.label}'),
                              trailing: ElevatedButton(
                                onPressed: () => _approve(repository, user.id),
                                child: const Text('Aprovar'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Usuários ativos',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (data.activeUsers.isEmpty)
                          const Text('Nenhum usuário ativo encontrado.')
                        else
                          ...data.activeUsers.map(
                            (user) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.brand.withValues(alpha: 0.12),
                                child: Text(user.name.isEmpty ? '?' : user.name[0]),
                              ),
                              title: Text(user.name),
                              subtitle: Text('${user.email} • ${user.role.label}'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserManagementData {
  const _UserManagementData({
    required this.pendingUsers,
    required this.activeUsers,
    this.warningMessage,
  });

  final List<AppUser> pendingUsers;
  final List<AppUser> activeUsers;
  final String? warningMessage;
}
