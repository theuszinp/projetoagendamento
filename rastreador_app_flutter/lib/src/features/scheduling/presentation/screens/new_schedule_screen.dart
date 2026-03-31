import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session_controller.dart';
import '../../../../core/utils/address_parser.dart';
import '../../../../core/utils/cep_formatter.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/utils/document_formatter.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../../address/data/via_cep_repository.dart';
import '../../../address/domain/cep_lookup_result.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../customers/domain/customer_lookup_result.dart';
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
  bool _isLookingUpCustomer = false;
  bool _customerLookupSucceeded = false;
  String? _cepFeedbackMessage;
  String? _customerFeedbackMessage;
  String? _lastCepLookupAttempt;
  String? _lastCustomerLookupAttempt;
  int? _existingCustomerId;

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

  void _handleDocumentChanged(String value) {
    final formatted = DocumentFormatter.format(value);
    if (formatted != value) {
      _documentController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final digits = DocumentFormatter.digitsOnly(formatted);
    if (_lastCustomerLookupAttempt != null && digits != _lastCustomerLookupAttempt) {
      setState(() {
        _existingCustomerId = null;
        _customerLookupSucceeded = false;
        _customerFeedbackMessage = null;
      });
    }

    if (DocumentFormatter.isValidLength(digits) &&
        digits != _lastCustomerLookupAttempt &&
        !_isLookingUpCustomer) {
      _lookupCustomer(autoTriggered: true);
    }
  }

  Future<void> _lookupCustomer({bool autoTriggered = false}) async {
    final repository = context.read<CustomerRepository>();
    final digits = DocumentFormatter.digitsOnly(_documentController.text);

    if (!DocumentFormatter.isValidLength(digits)) {
      if (!autoTriggered) {
        _showMessage('Informe um CPF ou CNPJ valido.');
      }
      return;
    }

    if (_isLookingUpCustomer) {
      return;
    }

    setState(() {
      _isLookingUpCustomer = true;
      _lastCustomerLookupAttempt = digits;
      _customerFeedbackMessage = null;
    });

    try {
      final customer = await repository.lookupByIdentifier(digits);
      if (!mounted) {
        return;
      }

      if (customer == null) {
        setState(() {
          _existingCustomerId = null;
          _customerLookupSucceeded = false;
          _customerFeedbackMessage =
              'Cliente nao encontrado. Voce pode continuar o cadastro normalmente.';
        });
        return;
      }

      _applyExistingCustomer(customer);
      setState(() {
        _existingCustomerId = customer.id;
        _customerLookupSucceeded = true;
        _customerFeedbackMessage =
            'Cliente encontrado na base. Nome, telefone e endereco foram preenchidos. O veiculo continua livre para outro carro.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _existingCustomerId = null;
        _customerLookupSucceeded = false;
        _customerFeedbackMessage = resolveErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLookingUpCustomer = false);
      }
    }
  }

  void _applyExistingCustomer(CustomerLookupResult customer) {
    _customerNameController.text =
        _preferLookupValue(customer.name, _customerNameController.text);
    _phoneController.text =
        _preferLookupValue(customer.phone, _phoneController.text);

    final parsedAddress = AddressParser.parse(customer.address);
    _streetController.text =
        _preferLookupValue(parsedAddress.street, _streetController.text);
    _numberController.text =
        _preferLookupValue(parsedAddress.number, _numberController.text);
    _complementController.text =
        _preferLookupValue(parsedAddress.complement, _complementController.text);
    _districtController.text =
        _preferLookupValue(parsedAddress.district, _districtController.text);
    _cityController.text =
        _preferLookupValue(parsedAddress.city, _cityController.text);
    _stateController.text = _preferLookupValue(
      parsedAddress.state.toUpperCase(),
      _stateController.text.toUpperCase(),
    );
    _cepController.text =
        _preferLookupValue(parsedAddress.cep, _cepController.text);
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
    if (_lastCepLookupAttempt != null && digits != _lastCepLookupAttempt) {
      setState(() {
        _cepLookupSucceeded = false;
        _cepFeedbackMessage = null;
      });
    }

    if (digits.length == 8 &&
        digits != _lastCepLookupAttempt &&
        !_isLookingUpCep) {
      _lookupCep(autoTriggered: true);
    }
  }

  Future<void> _lookupCep({bool autoTriggered = false}) async {
    final repository = context.read<ViaCepRepository>();
    final digits = CepFormatter.digitsOnly(_cepController.text);

    if (digits.length != 8) {
      if (!autoTriggered) {
        _showMessage('Informe um CEP com 8 digitos.');
      }
      return;
    }

    if (_isLookingUpCep) {
      return;
    }

    setState(() {
      _isLookingUpCep = true;
      _lastCepLookupAttempt = digits;
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
              'CEP nao encontrado. Voce pode preencher o endereco manualmente.';
        });
        return;
      }

      _applyCepLookupResult(result);
      setState(() {
        _cepLookupSucceeded = true;
        _cepFeedbackMessage =
            'Endereco localizado. Confira os campos e ajuste se precisar.';
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

  void _applyCepLookupResult(CepLookupResult result) {
    final formattedCep = CepFormatter.format(result.cep);
    _cepController.value = TextEditingValue(
      text: formattedCep,
      selection: TextSelection.collapsed(offset: formattedCep.length),
    );
    _streetController.text =
        _preferLookupValue(result.street, _streetController.text);
    _districtController.text =
        _preferLookupValue(result.neighborhood, _districtController.text);
    _cityController.text =
        _preferLookupValue(result.city, _cityController.text);
    _stateController.text = _preferLookupValue(
      result.state.toUpperCase(),
      _stateController.text.toUpperCase(),
    );

    if (result.complement.trim().isNotEmpty &&
        _complementController.text.trim().isEmpty) {
      _complementController.text = result.complement.trim();
    }
  }

  String _preferLookupValue(String lookupValue, String currentValue) {
    final normalizedLookup = lookupValue.trim();
    if (normalizedLookup.isEmpty) {
      return currentValue.trim();
    }
    return normalizedLookup;
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
        'Preencha os campos obrigatorios e selecione a data desejada.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final repository = context.read<ScheduleRepository>();
    final customerRepository = context.read<CustomerRepository>();
    final session = context.read<AppSessionController>();

    try {
      if (_existingCustomerId == null &&
          DocumentFormatter.isValidLength(_documentController.text)) {
        final customer = await customerRepository.lookupByIdentifier(
          DocumentFormatter.digitsOnly(_documentController.text),
        );

        if (customer != null) {
          _applyExistingCustomer(customer);
          _existingCustomerId = customer.id;
          _customerLookupSucceeded = true;
          _customerFeedbackMessage =
              'Cliente reutilizado automaticamente antes do envio.';
        }
      }

      await repository.createSchedule(
        requesterId: session.currentUserId,
        input: CreateScheduleInput(
          title: _titleController.text.trim(),
          serviceDescription: _descriptionController.text.trim(),
          priority: _priority,
          customer: Customer(
            id: _existingCustomerId,
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
        _customerLookupSucceeded = false;
        _cepFeedbackMessage = null;
        _customerFeedbackMessage = null;
        _lastCepLookupAttempt = null;
        _lastCustomerLookupAttempt = null;
        _existingCustomerId = null;
      });
      _showMessage('Solicitacao enviada com sucesso.', isError: false);
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
            _buildHero(context),
            const SizedBox(height: 18),
            _buildSection(
              context,
              title: 'Cliente',
              subtitle:
                  'Digite o CPF ou CNPJ para puxar o cadastro existente. Nome, telefone e endereco continuam editaveis.',
              children: [
                _buildCustomerLookupField(),
                _buildLookupBanner(
                  message: _customerFeedbackMessage,
                  success: _customerLookupSucceeded,
                ),
                _buildRequiredField(
                  _customerNameController,
                  'Nome do cliente',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                _buildRequiredField(
                  _phoneController,
                  'Telefone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _buildAddressFields(context),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Veiculo',
              subtitle:
                  'O veiculo nao e preenchido automaticamente, para permitir carros diferentes do mesmo cliente.',
              children: [
                _buildRequiredField(
                  _vehicleModelController,
                  'Modelo do veiculo',
                  icon: Icons.directions_car_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                _buildRequiredField(
                  _vehiclePlateController,
                  'Placa',
                  icon: Icons.pin_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildRequiredField(
                        _vehicleYearController,
                        'Ano',
                        icon: Icons.event_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vehicleColorController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Cor',
                          prefixIcon: Icon(Icons.palette_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Servico',
              subtitle:
                  'Informe o escopo tecnico, prioridade e a data desejada para o time operacional.',
              children: [
                _buildRequiredField(
                  _titleController,
                  'Titulo da solicitacao',
                  icon: Icons.assignment_outlined,
                ),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  validator: _requiredValidator,
                  decoration: const InputDecoration(
                    labelText: 'Descricao tecnica / escopo',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                DropdownButtonFormField<SchedulePriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
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
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(18),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data desejada',
                      prefixIcon: Icon(Icons.event_available_outlined),
                    ),
                    child: Text(
                      _desiredDate == null
                          ? 'Selecionar data e horario'
                          : DateTimeFormatter.shortDateTime(_desiredDate),
                    ),
                  ),
                ),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observacoes do vendedor',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
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

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.brandDark, AppColors.brand, AppColors.brandLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.20),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cadastro rapido e inteligente',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Puxe cliente por CPF/CNPJ, complete o endereco por CEP e deixe o time operacional receber uma solicitacao muito mais limpa.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(label: 'Cliente reutilizavel'),
              _HeroChip(label: 'Endereco automatico'),
              _HeroChip(label: 'Fluxo comercial agil'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerLookupField() {
    return TextFormField(
      controller: _documentController,
      validator: _documentValidator,
      keyboardType: TextInputType.number,
      onChanged: _handleDocumentChanged,
      decoration: InputDecoration(
        labelText: 'CPF / CNPJ',
        prefixIcon: const Icon(Icons.badge_outlined),
        suffixIcon: _isLookingUpCustomer
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: 'Buscar cliente',
                onPressed: _lookupCustomer,
                icon: const Icon(Icons.search),
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
                  prefixIcon: const Icon(Icons.location_searching_outlined),
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
              child: _buildRequiredField(
                _numberController,
                'Numero',
                icon: Icons.looks_one_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        _buildLookupBanner(
          message: _cepFeedbackMessage,
          success: _cepLookupSucceeded,
        ),
        _buildRequiredField(
          _streetController,
          'Logradouro',
          icon: Icons.alt_route_outlined,
          textCapitalization: TextCapitalization.words,
        ),
        TextFormField(
          controller: _complementController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Complemento',
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
        ),
        _buildRequiredField(
          _districtController,
          'Bairro',
          icon: Icons.location_city_outlined,
          textCapitalization: TextCapitalization.words,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildRequiredField(
                _cityController,
                'Cidade',
                icon: Icons.location_on_outlined,
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
                decoration: const InputDecoration(
                  labelText: 'UF',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLookupBanner({
    required String? message,
    required bool success,
  }) {
    if ((message ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final color = success ? AppColors.success : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.info_outline,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: 18),
            ...children.expand((child) => [child, const SizedBox(height: 12)]),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredField(
    TextEditingController controller,
    String label, {
    required IconData icon,
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatorio';
    }
    return null;
  }

  String? _documentValidator(String? value) {
    if (!DocumentFormatter.isValidLength(value ?? '')) {
      return 'Informe um CPF ou CNPJ valido';
    }
    return null;
  }

  String? _cepValidator(String? value) {
    final digits = CepFormatter.digitsOnly(value ?? '');
    if (digits.length != 8) {
      return 'Informe um CEP valido';
    }
    return null;
  }

  String? _stateValidator(String? value) {
    if (value == null || value.trim().length != 2) {
      return 'UF invalida';
    }
    return null;
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
