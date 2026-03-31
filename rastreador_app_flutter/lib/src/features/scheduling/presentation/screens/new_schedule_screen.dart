import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session_controller.dart';
import '../../../../core/utils/cep_formatter.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../../address/data/via_cep_repository.dart';
import '../../../address/domain/cep_lookup_result.dart';
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
  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _notesController = TextEditingController();

  SchedulePriority _priority = SchedulePriority.medium;
  DateTime? _desiredDate;
  bool _isSubmitting = false;
  bool _isLookingUpCep = false;
  bool _cepLookupSucceeded = false;
  String? _cepFeedbackMessage;
  String? _lastLookupAttempt;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customerNameController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _stateController.dispose();
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

  void _handleCepChanged(String value) {
    final formatted = CepFormatter.format(value);
    if (formatted != value) {
      _cepController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final digits = CepFormatter.digitsOnly(formatted);
    if (_lastLookupAttempt != null && digits != _lastLookupAttempt) {
      setState(() {
        _cepLookupSucceeded = false;
        _cepFeedbackMessage = null;
      });
    }

    if (digits.length == 8 &&
        digits != _lastLookupAttempt &&
        !_isLookingUpCep) {
      _lookupCep(autoTriggered: true);
    }
  }

  Future<void> _lookupCep({bool autoTriggered = false}) async {
    final repository = context.read<ViaCepRepository>();
    final digits = CepFormatter.digitsOnly(_cepController.text);

    if (digits.length != 8) {
      if (!autoTriggered) {
        _showMessage('Informe um CEP com 8 dígitos.');
      }
      return;
    }

    if (_isLookingUpCep) {
      return;
    }

    setState(() {
      _isLookingUpCep = true;
      _lastLookupAttempt = digits;
      _cepFeedbackMessage = null;
    });

    try {
      final result = await repository.lookupByCep(digits);
      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _cepLookupSucceeded = false;
          _cepFeedbackMessage =
              'CEP não encontrado. Você pode preencher o endereço manualmente.';
        });
        return;
      }

      _applyLookupResult(result);
      setState(() {
        _cepLookupSucceeded = true;
        _cepFeedbackMessage =
            'Endereço localizado. Confira e edite os campos se precisar.';
      });
    } on ViaCepException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cepLookupSucceeded = false;
        _cepFeedbackMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _isLookingUpCep = false);
      }
    }
  }

  void _applyLookupResult(CepLookupResult result) {
    final formattedCep = CepFormatter.format(result.cep);
    _cepController.value = TextEditingValue(
      text: formattedCep,
      selection: TextSelection.collapsed(offset: formattedCep.length),
    );
    _streetController.text = _mergeLookupValue(
      lookupValue: result.street,
      currentValue: _streetController.text,
    );
    _districtController.text = _mergeLookupValue(
      lookupValue: result.neighborhood,
      currentValue: _districtController.text,
    );
    _cityController.text = _mergeLookupValue(
      lookupValue: result.city,
      currentValue: _cityController.text,
    );
    _stateController.text = _mergeLookupValue(
      lookupValue: result.state.toUpperCase(),
      currentValue: _stateController.text.toUpperCase(),
    );

    if (result.complement.trim().isNotEmpty &&
        _complementController.text.trim().isEmpty) {
      _complementController.text = result.complement.trim();
    }
  }

  String _mergeLookupValue({
    required String lookupValue,
    required String currentValue,
  }) {
    final normalizedLookup = lookupValue.trim();
    if (normalizedLookup.isNotEmpty) {
      return normalizedLookup;
    }

    return currentValue.trim();
  }

  String _buildFullAddress() {
    final cep = CepFormatter.format(_cepController.text.trim());
    final street = _streetController.text.trim();
    final number = _numberController.text.trim();
    final complement = _complementController.text.trim();
    final district = _districtController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim().toUpperCase();

    final buffer = StringBuffer('$street, $number');
    if (complement.isNotEmpty) {
      buffer.write(', $complement');
    }
    buffer.write(' - $district, $city/$state');
    if (cep.isNotEmpty) {
      buffer.write(' - CEP $cep');
    }

    return buffer.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _desiredDate == null) {
      _showMessage(
        'Preencha todos os campos obrigatórios e selecione a data desejada.',
      );
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
          address: Address(
            fullText: _buildFullAddress(),
            reference: 'CEP ${CepFormatter.format(_cepController.text)}',
          ),
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
        _cepLookupSucceeded = false;
        _cepFeedbackMessage = null;
        _lastLookupAttempt = null;
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
    _cepController.clear();
    _streetController.clear();
    _numberController.clear();
    _complementController.clear();
    _districtController.clear();
    _cityController.clear();
    _stateController.clear();
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
            Text(
              'Cadastro rápido para o vendedor',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Digite o CEP para buscar o endereço automaticamente. Mesmo quando a API encontrar o local, todos os campos continuam editáveis.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'Cliente',
              children: [
                _requiredField(_customerNameController, 'Nome do cliente'),
                _requiredField(_documentController, 'CPF/CNPJ'),
                _requiredField(
                  _phoneController,
                  'Telefone',
                  keyboardType: TextInputType.phone,
                ),
                _buildAddressFields(context),
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
                    Expanded(
                      child: _requiredField(
                        _vehicleYearController,
                        'Ano',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vehicleColorController,
                        textCapitalization: TextCapitalization.words,
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

  Widget _buildAddressFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _cepController,
                keyboardType: TextInputType.number,
                validator: _cepValidator,
                onChanged: _handleCepChanged,
                decoration: InputDecoration(
                  labelText: 'CEP',
                  hintText: '00000-000',
                  suffixIcon: _isLookingUpCep
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Buscar CEP',
                          onPressed: _lookupCep,
                          icon: const Icon(Icons.search),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _requiredField(
                _numberController,
                'Número',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        if ((_cepFeedbackMessage ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_cepLookupSucceeded
                      ? AppColors.brand
                      : AppColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (_cepLookupSucceeded
                        ? AppColors.brand
                        : AppColors.warning)
                    .withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _cepLookupSucceeded ? Icons.check_circle : Icons.info_outline,
                  color: _cepLookupSucceeded
                      ? AppColors.brand
                      : AppColors.textPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _cepFeedbackMessage!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _requiredField(
          _streetController,
          'Logradouro',
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _complementController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Complemento'),
        ),
        const SizedBox(height: 12),
        _requiredField(
          _districtController,
          'Bairro',
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _requiredField(
                _cityController,
                'Cidade',
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _stateController,
                validator: _stateValidator,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(2)],
                decoration: const InputDecoration(labelText: 'UF'),
              ),
            ),
          ],
        ),
      ],
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
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
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

  String? _cepValidator(String? value) {
    final digits = CepFormatter.digitsOnly(value ?? '');
    if (digits.length != 8) {
      return 'Informe um CEP válido';
    }

    return null;
  }

  String? _stateValidator(String? value) {
    if (value == null || value.trim().length != 2) {
      return 'UF inválida';
    }

    return null;
  }
}
