# Arquitetura do Sistema de Agendamento de Instalação

## Objetivo do produto

Criar um sistema de agendamento de instalação com fluxo previsível, código modular, responsabilidades separadas e base pronta para crescer em:

- novos status operacionais
- métricas
- anexos e fotos
- observações técnicas e internas
- agenda visual por equipe
- trilha de auditoria

## Estrutura final recomendada

### Backend implementado nesta evolução

```text
backend/
  server.js
  src/
    app.js
    server.js
    config/
      env.js
      db.js
      firebase.js
    shared/
      constants/
        roles.js
        permissions.js
        schedule-status.js
      errors/
        app-error.js
        error-handler.js
      middleware/
        auth.js
        permissions.js
        validate-request.js
      utils/
        date.js
        identifier.js
        pagination.js
      validators/
        auth.validator.js
        schedule.validator.js
        user.validator.js
    modules/
      auth/
        auth.controller.js
        auth.service.js
        auth.repository.js
        auth.routes.js
      users/
        users.controller.js
        users.service.js
        users.repository.js
        users.routes.js
      customers/
        customers.controller.js
        customers.service.js
        customers.repository.js
        customers.routes.js
      vehicles/
        vehicles.controller.js
        vehicles.service.js
        vehicles.repository.js
        vehicles.routes.js
      schedules/
        schedules.controller.js
        schedules.service.js
        schedules.repository.js
        schedules.routes.js
        schedule-history.service.js
      reports/
        reports.controller.js
        reports.service.js
        reports.routes.js
```

### Flutter implementado no app

```text
rastreador_app_flutter/lib/
  main.dart
  src/
    app/
      app.dart
      app_dependencies.dart
      router/
        app_router.dart
        app_routes.dart
      theme/
        app_colors.dart
        app_theme.dart
    core/
      network/
        api_client.dart
        api_config.dart
      permissions/
        app_permission.dart
        permission_matrix.dart
      session/
        app_session_controller.dart
        session_storage.dart
      utils/
        date_time_formatter.dart
        schedule_description_codec.dart
      widgets/
        empty_state.dart
        loading_view.dart
        metric_card.dart
        section_header.dart
        status_badge.dart
    features/
      shared/
        presentation/
          splash_screen.dart
      users/
        domain/
          app_user.dart
          technician_workload.dart
          user_role.dart
        data/
          auth_repository.dart
          user_repository.dart
        presentation/
          login_screen.dart
          register_screen.dart
          user_management_screen.dart
      scheduling/
        domain/
          address.dart
          create_schedule_input.dart
          customer.dart
          installation_schedule.dart
          schedule_filters.dart
          schedule_priority.dart
          schedule_status.dart
          schedule_timeline_entry.dart
          vehicle.dart
        data/
          schedule_repository.dart
        presentation/
          controllers/
            admin_schedule_board_controller.dart
            seller_schedule_list_controller.dart
            technician_agenda_controller.dart
          screens/
            admin_dashboard_screen.dart
            admin_schedule_board_screen.dart
            new_schedule_screen.dart
            schedule_details_screen.dart
            seller_dashboard_screen.dart
            seller_schedule_list_screen.dart
            technician_agenda_screen.dart
            technician_dashboard_screen.dart
            technician_job_details_screen.dart
          widgets/
            schedule_card.dart
            schedule_filters_bar.dart
            schedule_timeline_card.dart
```

## Perfis e regras de acesso

### Vendedor

- cria cliente e veículo no fluxo da solicitação
- solicita agendamento
- informa data desejada, endereço e observações
- acompanha apenas seus próprios agendamentos
- consulta timeline e retorno do admin

### Admin

- visualiza todos os agendamentos
- aprova ou reprova solicitações
- atribui e reatribui instalador
- visualiza carga por instalador
- acompanha indicadores
- gerencia usuários e aprova novos acessos
- registra notas internas

### Instalador

- visualiza somente serviços atribuídos a ele
- acompanha agenda operacional
- inicia e conclui atendimento
- no fluxo alvo também registra foto, ocorrência e reagendamento

## RBAC recomendado

| Ação | Seller | Admin | Installer |
|---|---:|---:|---:|
| Criar agendamento | Sim | Opcional | Não |
| Ver próprios agendamentos | Sim | Sim | Não |
| Ver todos agendamentos | Não | Sim | Não |
| Aprovar/reprovar | Não | Sim | Não |
| Atribuir instalador | Não | Sim | Não |
| Alterar status técnico | Não | Não | Sim |
| Gerir usuários | Não | Sim | Não |
| Ver relatórios | Não | Sim | Opcional |

## Fluxo de negócio profissional

### Status alvo

1. `pending_approval`
2. `approved`
3. `scheduled`
4. `on_route`
5. `in_service`
6. `completed`
7. `reschedule_requested`
8. `rescheduled`
9. `cancelled`
10. `not_completed`
11. `technical_issue`
12. `rejected`

### Transições principais

1. vendedor cria solicitação
2. sistema registra `pending_approval`
3. admin analisa disponibilidade, dados do cliente e prioridade
4. admin reprova ou aprova
5. se aprovar, vincula instalador e agenda vira `scheduled`
6. instalador confirma recebimento
7. instalador entra em deslocamento
8. instalador inicia o serviço e status vira `in_service`
9. instalador conclui ou registra impedimento
10. sistema grava timeline, observações e log de alteração

### Estado atual do backend

Hoje a API ainda trabalha com um fluxo reduzido:

- `PENDING`
- `APPROVED`
- `REJECTED`
- `tech_status = IN_PROGRESS | COMPLETED`

O app já foi preparado para a modelagem completa, mas alguns estados avançados ainda dependem de endpoints e persistência no backend.

## Entidades do sistema

### User

- `id`
- `name`
- `email`
- `role`
- `approved`
- `blocked_at`
- `created_at`
- `updated_at`

### Customer

- `id`
- `name`
- `document`
- `phone`
- `address_id`
- `created_by`

### Vehicle

- `id`
- `customer_id`
- `plate`
- `model`
- `brand`
- `year`
- `color`
- `notes`

### Address

- `id`
- `zip_code`
- `street`
- `number`
- `district`
- `city`
- `state`
- `complement`
- `reference`

### InstallationSchedule

- `id`
- `protocol`
- `customer_id`
- `vehicle_id`
- `seller_id`
- `installer_id`
- `status`
- `priority`
- `desired_date`
- `scheduled_start`
- `scheduled_end`
- `service_type`
- `seller_notes`
- `admin_notes`
- `technical_notes`
- `created_at`
- `approved_at`
- `started_at`
- `completed_at`

### ScheduleStatusHistory

- `id`
- `schedule_id`
- `from_status`
- `to_status`
- `changed_by`
- `changed_at`
- `reason`

### Attachment

- `id`
- `schedule_id`
- `type`
- `url`
- `uploaded_by`
- `created_at`

### AuditLog

- `id`
- `entity`
- `entity_id`
- `action`
- `before_payload`
- `after_payload`
- `changed_by`
- `created_at`

## Validações obrigatórias

- cliente deve ter nome, documento e telefone
- agendamento deve ter endereço válido
- veículo deve ter ao menos modelo e placa
- data desejada não pode estar no passado
- instalador não pode ser duplicado no mesmo slot
- conclusão deve exigir início prévio
- alteração sensível deve gerar histórico

## Funções organizadas por responsabilidade

### Autenticação

- `login`
- `logout`
- `restoreSession`
- `registerUser`
- `approveUser`

### Agendamento

- `createSchedule`
- `fetchSellerSchedules`
- `fetchAdminSchedules`
- `fetchTechnicianSchedules`
- `approveSchedule`
- `rejectSchedule`
- `assignInstaller`
- `startService`
- `completeService`

### Histórico e observações

- `appendStatusHistory`
- `appendAdminNote`
- `appendTechnicalNote`
- `listScheduleTimeline`

### Agenda e relatórios

- `listAgendaByInstaller`
- `listAgendaByDay`
- `listAgendaByPeriod`
- `listSchedulesByStatus`
- `fetchTechnicianWorkloads`
- `fetchDashboardMetrics`

### Permissões

- `hasPermission(role, permission)`
- `guardRouteByRole`
- `hideActionByPermission`

## Navegação ideal

### Comum

- login
- cadastro
- splash

### Vendedor

- dashboard do vendedor
- novo agendamento
- meus agendamentos
- detalhe do agendamento

### Admin

- dashboard admin
- agenda geral
- detalhe do agendamento
- gestão de usuários
- relatórios

### Instalador

- dashboard do instalador
- minha agenda
- detalhe do serviço

## Padrões técnicos adotados

- serviço HTTP centralizado em `ApiClient`
- repositórios por domínio
- estado de sessão isolado em `AppSessionController`
- UI sem chamada direta de endpoint bruto
- controllers por fluxo de tela
- enums para status, prioridade e papéis
- widgets reutilizáveis para métricas, badges, timeline e estados vazios
- roteamento centralizado com guarda por perfil
- documentação explícita de arquitetura e RBAC

## Entregas já adicionadas no backend nesta evolução

- `server.js` agora sobe uma app modular via `src/app.js`
- aliases compatíveis em `/tickets`, `/ticket` e `/schedules`
- módulos separados para `auth`, `users`, `customers`, `schedules` e `reports`
- bootstrap de banco com histórico e observações em `ticket_status_history` e `ticket_notes`
- novos endpoints:
  - `GET /schedules/:id`
  - `GET /schedules/:id/history`
  - `GET /schedules/:id/notes`
  - `POST /schedules/:id/notes`

## Próximos passos recomendados no backend

1. Criar módulo `schedules` com service e repository próprios.
2. Persistir veículo, histórico, anexos e observações em tabelas separadas.
3. Substituir `status + tech_status` por uma máquina de estados única.
4. Expor endpoints para:
   - `POST /schedules/:id/notes`
   - `POST /schedules/:id/attachments`
   - `POST /schedules/:id/reschedule-request`
   - `PUT /schedules/:id/cancel`
   - `GET /schedules/:id/history`
5. Criar validação centralizada e logs de auditoria.

## Resultado esperado com essa arquitetura

- frontend previsível e fácil de manter
- backend pronto para evoluir por módulo
- regras de negócio explícitas
- menos duplicação
- melhor UX para operação em campo
- melhor governança para admin
- onboarding mais simples para novos desenvolvedores
