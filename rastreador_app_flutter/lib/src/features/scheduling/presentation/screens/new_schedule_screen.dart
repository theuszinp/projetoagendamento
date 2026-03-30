import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session_controller.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../data/schedule_repository.dart';
import '../../domain/address.dart';
import '../../domain/create_schedule_input.dart';
import '../../domain/customer.dart';
import '../../domain/schedule_priority.dart';
import '../../domain/vehicle.dart';

class NewScheduleScreen extends StatefulWidget {
  const NewScheduleScreen({super.key});

  @override
  State<NewScheduleScreen> createState() => _NewScheduleScreenState();
}

class _NewScheduleScreenState extends State<NewScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _documentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _notesController = TextEditingController();

  SchedulePriority _priority = SchedulePriority.medium;
  DateTime? _desiredDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customerNameController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: _desiredDate ?? now,
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_desiredDate ?? now),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _desiredDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _desiredDate == null) {
      _showMessage('Preencha todos os campos obrigatórios e selecione a data desejada.');
      return;
    }

    setState(() => _isSubmitting = true);

    final repository = context.read<ScheduleRepository>();
    final session = context.read<AppSessionController>();

    try {
      await repository.createSchedule(
        requesterId: session.currentUserId,
        input: CreateScheduleInput(
          title: _titleController.text.trim(),
          serviceDescription: _descriptionController.text.trim(),
          priority: _priority,
          customer: Customer(
            name: _customerNameController.text.trim(),
            document: _documentController.text.trim(),
            phone: _phoneController.text.trim(),
          ),
          address: Address(fullText: _addressController.text.trim()),
          vehicle: Vehicle(
            model: _vehicleModelController.text.trim(),
            plate: _vehiclePlateController.text.trim(),
            year: _vehicleYearController.text.trim(),
            color: _vehicleColorController.text.trim(),
          ),
          desiredDate: _desiredDate!,
          sellerNotes: _notesController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      _formKey.currentState!.reset();
      _clearControllers();
      setState(() {
        _priority = SchedulePriority.medium;
        _desiredDate = null;
      });
      _showMessage('Solicitação enviada com sucesso.', isError: false);
    } catch (error) {
      _showMessage(resolveErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearControllers() {
    _titleController.clear();
    _descriptionController.clear();
    _customerNameController.clear();
    _documentController.clear();
    _phoneController.clear();
    _addressController.clear();
    _vehicleModelController.clear();
    _vehiclePlateController.clear();
    _vehicleYearController.clear();
    _vehicleColorController.clear();
    _notesController.clear();
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo agendamento'),
        actions: const [SessionAppBarActions()],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Cadastro rápido para o vendedor',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'A regra é simples: dados completos de cliente, veículo e operação antes de enviar para aprovação.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'Cliente',
              children: [
                _requiredField(_customerNameController, 'Nome do cliente'),
                _requiredField(_documentController, 'CPF/CNPJ'),
                _requiredField(_phoneController, 'Telefone'),
                _requiredField(_addressController, 'Endereço da instalação', maxLines: 2),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Veículo',
              children: [
                _requiredField(_vehicleModelController, 'Modelo do veículo'),
                _requiredField(_vehiclePlateController, 'Placa'),
                Row(
                  children: [
                    Expanded(child: _requiredField(_vehicleYearController, 'Ano')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vehicleColorController,
                        decoration: const InputDecoration(labelText: 'Cor'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Serviço',
              children: [
                _requiredField(_titleController, 'Título da solicitação'),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  validator: _requiredValidator,
                  decoration: const InputDecoration(
                    labelText: 'Descrição técnica / escopo',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SchedulePriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Prioridade'),
                  items: SchedulePriority.values
                      .map(
                        (priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _priority = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(18),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data desejada',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(
                      _desiredDate == null
                          ? 'Selecionar data e horário'
                          : DateTimeFormatter.shortDateTime(_desiredDate),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observações do vendedor',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Solicitar agendamento'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children.expand((child) => [child, const SizedBox(height: 12)]),
          ],
        ),
      ),
    );
  }

  Widget _requiredField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: _requiredValidator,
      decoration: InputDecoration(labelText: label),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }

    return null;
  }
}
