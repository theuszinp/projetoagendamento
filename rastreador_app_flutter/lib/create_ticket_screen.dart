import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import necessário para o Filter
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Substitua pelo seu BASE_URL
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

class CreateTicketScreen extends StatefulWidget {
  // Recebe o ID do usuário logado (requested_by) da HomeScreen
  final int requestedByUserId;
  
  const CreateTicketScreen({
    super.key, 
    required this.requestedByUserId,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  // Chave para validação do formulário
  final _formKey = GlobalKey<FormState>();
  
  // Variáveis CRÍTICAS para a API
  int? _clientId; // ID numérico retornado pela busca (OPCIONAL)
  String? _selectedPriority; // Prioridade do serviço (OBRIGATÓRIO para a API)

  // Controladores
  final TextEditingController _titleController = TextEditingController(); 
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _identifierController = TextEditingController(); // Usado para busca (CPF/CNPJ)
  final TextEditingController _phoneNumberController = TextEditingController(); // <--- NOVO CONTROLADOR PARA O NÚMERO
  
  bool _isLoading = false;
  bool _isSearching = false;

  final List<String> _priorities = ['Baixa', 'Média', 'Alta'];
  
  // Novo estado: Se o nome e endereço foram preenchidos pela busca, eles ficam somente leitura.
  bool _isClientDataReadOnly = false;

  @override
  void dispose() {
    _titleController.dispose();
    _customerNameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _identifierController.dispose();
    _phoneNumberController.dispose(); // <--- DISPOSE NOVO CONTROLADOR
    super.dispose();
  }

  // ===========================================
  // 1. Lógica de Busca de Cliente (/clients/search)
  // ===========================================
  Future<void> _searchClient() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showSnackBar('Obrigatório informar CPF/CNPJ para buscar.', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _clientId = null; // Reseta o ID do cliente
      _isClientDataReadOnly = false; // Permite edição enquanto busca
      _customerNameController.clear();
      _addressController.clear();
      // _phoneNumberController.clear(); // Não limpamos o número, pois ele é opcional na busca
    });

    try {
      final url = Uri.parse('$API_BASE_URL/clients/search?identifier=$identifier');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (mounted) {
          setState(() {
            // Cliente encontrado: preenche os campos e os torna somente leitura
            _clientId = data['id']; 
            _customerNameController.text = data['name'] ?? 'Cliente sem nome';
            _addressController.text = data['address'] ?? 'Endereço não fornecido';
            // Se a API retornar o telefone, preencha:
            _phoneNumberController.text = data['phoneNumber'] ?? ''; // <--- Puxa o número se houver
            _isClientDataReadOnly = true; 
          });
        }
        _showSnackBar('✅ Cliente encontrado com sucesso!', Colors.green);
      } else {
        // Cliente NÃO encontrado: limpa e mantém campos editáveis.
        if (mounted) {
          setState(() {
            _customerNameController.clear();
            _addressController.clear();
            _isClientDataReadOnly = false; 
          });
        }
        _showSnackBar('⚠️ Cliente não encontrado. Preencha os dados manualmente.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('❌ Erro de conexão ao buscar cliente.', Colors.deepOrange);
      // ignore: avoid_print
      print('Erro ao buscar cliente: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // ===========================================
  // 2. Lógica de Envio de Ticket (POST /ticket)
  // ===========================================
  Future<void> _submitTicket() async {
    // 1. Validação do formulário Flutter
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Validação dos campos obrigatórios que não usam o validador nativo do FormField
    if (_selectedPriority == null) {
      _showSnackBar('⚠️ A prioridade do agendamento é obrigatória.', Colors.red);
      return;
    }
    
    if (_customerNameController.text.trim().isEmpty) {
        _showSnackBar('⚠️ O Nome do Cliente é obrigatório.', Colors.red);
        return;
    }
    if (_addressController.text.trim().isEmpty) {
        _showSnackBar('⚠️ O Endereço de Instalação é obrigatório.', Colors.red);
        return;
    }
    // 🚨 NOVA VALIDAÇÃO: Número do Cliente
    if (_phoneNumberController.text.trim().isEmpty) {
        _showSnackBar('⚠️ O Número de Contato do Cliente é obrigatório.', Colors.red);
        return;
    }


    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Cria o mapa de dados básicos
      final Map<String, dynamic> body = {
        'title': _titleController.text.trim(), 
        'description': _descriptionController.text.trim(),
        'priority': _selectedPriority, 
        'requestedBy': widget.requestedByUserId,
        'customerName': _customerNameController.text.trim(), // Enviamos sempre o nome digitado/puxado
        'address': _addressController.text.trim(), // Enviamos sempre o endereço digitado/puxado
        // 🚨 DADO NOVO: Adiciona o número de telefone
        'phoneNumber': _phoneNumberController.text.trim(), 
        // 🚨 CORREÇÃO: Adiciona o identificador (CPF/CNPJ) à requisição
        // O backend precisa disso para criar um novo cliente se o 'clientId' for nulo.
        'identifier': _identifierController.text.trim(),
      };

      // Adiciona 'clientId' SOMENTE se ele NÃO for nulo (cliente existente).
      if (_clientId != null) {
        body['clientId'] = _clientId;
      }

      final response = await http.post(
        Uri.parse('$API_BASE_URL/ticket'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        _formKey.currentState!.reset();
        _clearForm();
        _showSnackBar('✅ Agendamento criado com sucesso! Pendente de aprovação do Admin.', Colors.green);
      } else {
        final errorData = jsonDecode(response.body);
        String message = errorData['error'] ?? 'Falha ao criar agendamento.';
        _showSnackBar('⚠️ Erro: $message', Colors.red);
      }
    } catch (e) {
      _showSnackBar('❌ Erro de conexão. Verifique a API/Internet.', Colors.deepOrange);
      // ignore: avoid_print
      print('Erro ao enviar ticket: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper para limpar formulário e IDs
  void _clearForm() {
    if (!mounted) return;
    setState(() {
      _clientId = null;
      _selectedPriority = null;
      _isClientDataReadOnly = false;
    });
    _titleController.clear();
    _customerNameController.clear();
    _addressController.clear();
    _descriptionController.clear();
    _identifierController.clear();
    _phoneNumberController.clear(); // <--- LIMPA O NOVO CONTROLADOR
  }

  // Helper para SnackBar
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Agendamento'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- 1. SEÇÃO DE BUSCA (OPCIONAL) ---
              Text(
                'Buscar Cliente por Identificador (Opcional)',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor),
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.text,
                      decoration: _buildInputDecoration('CPF/CNPJ do Cliente (Opcional)', LucideIcons.scan),
                      // Removendo o validador para tornar o campo opcional
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão de Busca
                  _isSearching 
                      ? const SizedBox(
                          width: 48, 
                          height: 48, 
                          child: Center(child: CircularProgressIndicator()))
                      : IconButton(
                          icon: Icon(LucideIcons.search, size: 28, color: theme.primaryColor),
                          onPressed: _searchClient,
                          tooltip: 'Buscar Cliente',
                        ),
                ],
              ),
              const SizedBox(height: 30),

              // --- 2. DADOS DO CLIENTE (MANUAL OU AUTO) ---
              Text(
                'Dados do Cliente (Obrigatório)',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor),
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 15),

              // Campo Nome do Cliente (Agora pode ser editável)
              TextFormField(
                controller: _customerNameController,
                readOnly: _isClientDataReadOnly, // Somente leitura se encontrado na busca
                decoration: _buildInputDecoration(
                  _isClientDataReadOnly ? 'Nome Completo (Preenchido Automaticamente)' : 'Nome Completo (Obrigatório)', 
                  LucideIcons.user
                ).copyWith(
                  filled: _isClientDataReadOnly, // Realça se for automático
                  fillColor: _isClientDataReadOnly ? Colors.grey[100] : Colors.white,
                ),
                validator: (value) {
                  // A validação de obrigatoriedade agora é feita no _submitTicket
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // 🚨 NOVO CAMPO: NÚMERO DO CLIENTE
              TextFormField(
                controller: _phoneNumberController,
                readOnly: _isClientDataReadOnly, // Somente leitura se encontrado na busca
                keyboardType: TextInputType.phone, // Teclado numérico
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Permite apenas números
                ],
                decoration: _buildInputDecoration(
                  _isClientDataReadOnly ? 'Número de Contato (Auto)' : 'Número de Contato (Obrigatório)', 
                  LucideIcons.phone
                ).copyWith(
                  filled: _isClientDataReadOnly, // Realça se for automático
                  fillColor: _isClientDataReadOnly ? Colors.grey[100] : Colors.white,
                ),
                validator: (value) {
                  // A validação de obrigatoriedade agora é feita no _submitTicket
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Campo Endereço (Agora pode ser editável)
              TextFormField(
                controller: _addressController,
                readOnly: _isClientDataReadOnly, // Somente leitura se encontrado na busca
                maxLines: 3,
                keyboardType: TextInputType.streetAddress,
                decoration: _buildInputDecoration(
                  _isClientDataReadOnly ? 'Endereço (Preenchido Automaticamente)' : 'Endereço de Instalação (Obrigatório)', 
                  LucideIcons.mapPin
                ).copyWith(
                  filled: _isClientDataReadOnly, // Realça se for automático
                  fillColor: _isClientDataReadOnly ? Colors.grey[100] : Colors.white,
                ),
                validator: (value) {
                  // A validação de obrigatoriedade agora é feita no _submitTicket
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // --- 3. DADOS DO TICKET ---
              Text(
                'Detalhes do Agendamento',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor),
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 15),

              // Campo Título (OBRIGATÓRIO)
              TextFormField(
                controller: _titleController,
                decoration: _buildInputDecoration('Título do Serviço (Ex: Instalação Padrão)', LucideIcons.tag),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'O título é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Dropdown de Prioridade (OBRIGATÓRIO)
              DropdownButtonFormField<String>(
                decoration: _buildInputDecoration('Prioridade do Serviço', LucideIcons.zap),
                value: _selectedPriority,
                items: _priorities.map((String priority) {
                  return DropdownMenuItem<String>(
                    value: priority,
                    child: Text(priority),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPriority = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecione a prioridade.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              
              // Campo Descrição/Detalhes
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _buildInputDecoration('Descrição (Detalhes do Serviço)', LucideIcons.clipboardList),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'A descrição é obrigatória.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Botão de Envio
              ElevatedButton(
                onPressed: (_isLoading || _isSearching) ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : const Text(
                        'Registrar Agendamento', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para padronizar a decoração dos campos
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.all(15.0),
    );
  }
}