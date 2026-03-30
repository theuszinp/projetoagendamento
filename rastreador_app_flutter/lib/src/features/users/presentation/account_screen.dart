import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_controller.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_header.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<Map<String, dynamic>> _loadSystemInfo(BuildContext context) async {
    try {
      return await context.read<ApiClient>().getJson('/');
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSessionController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Conta e sessão')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadSystemInfo(context),
        builder: (context, snapshot) {
          final systemInfo = snapshot.data ?? const <String, dynamic>{};
          final version = (systemInfo['version'] ?? 'Desconhecida').toString();
          final isLegacyBackend = !version.contains('4.');

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionHeader(
                title: 'Sessão do usuário',
                subtitle:
                    'Área para sair com segurança, conferir versão da API e acompanhar compatibilidade.',
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                          child: Text(
                            session.currentUser?.name.isNotEmpty == true
                                ? session.currentUser!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          session.currentUser?.name ?? 'Usuário',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        subtitle: Text(
                          '${session.currentUser?.email ?? ''}\n${session.role.label}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const LoadingView(label: 'Consultando backend...')
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (isLegacyBackend
                                    ? AppColors.warning
                                    : AppColors.brand)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Versão da API: $version',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isLegacyBackend
                                    ? 'O app está pronto para a API 4.x. Se algumas funções avançadas não aparecerem, faça o deploy do backend novo.'
                                    : 'Backend compatível com histórico, notas e módulos novos.',
                              ),
                            ],
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ações rápidas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await context.read<AppSessionController>().logout();
                        },
                        icon: const Icon(Icons.logout),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                        ),
                        label: const Text('Sair da conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
