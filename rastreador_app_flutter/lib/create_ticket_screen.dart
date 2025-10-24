import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

// Substitua pelo seu BASE_URL
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

class CreateTicketScreen extends StatefulWidget {
  // Recebe o ID do usuário logado (requested_by) da HomeScreen
  final int requestedByUserId;
  // 💡 NOVIDADE: Recebe o token de autenticação
  final String authToken;

  const CreateTicketScreen({
    super.key,
    required this.requestedByUserId,
    required this.authToken, // 💡 OBRIGATÓRIO PASSAR O TOKEN AGORA
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
  final TextEditingController _identifierController =
      TextEditingController(); // Usado para busca (CPF/CNPJ)
  final TextEditingController _phoneNumberController = TextEditingController();

  bool _isLoading = false;
  bool _isSearching = false;

  final List<String> _priorities = ['Baixa', 'Média', 'Alta'];

  // Novo estado: Se o nome e endereço foram preenchidos pela busca, eles ficam somente leitura.
  // MANTENHA ESTA VARIÁVEL
  bool _isClientDataReadOnly = false;

  // Variável para travar o campo do CPF/CNPJ (identifier) após a busca bem sucedida
  bool _isIdentifierReadOnly = false;

  @override
  void dispose() {
    _titleController.dispose();
    _customerNameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _identifierController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // ===========================================
  // 1. Lógica de Busca de Cliente (/clients/search)
  // ===========================================
  Future<void> _searchClient() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showSnackBar(
          'Obrigatório informar CPF/CNPJ para buscar.', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _clientId = null; // Reseta o ID do cliente
      // Ao iniciar a busca/limpar, permite edição e identificador editável
      _isClientDataReadOnly = false;
      _isIdentifierReadOnly = false;
      _customerNameController.clear();
      _addressController.clear();
      _phoneNumberController.clear();
    });

    try {
      final url =
          Uri.parse('$API_BASE_URL/clients/search?identifier=$identifier');
      final response = await http.get(
        url,
        // 💡 Adicionado o token para proteger a rota de busca de clientes
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            // O cliente foi encontrado: preenche os campos
            _clientId = data['id'];
            _customerNameController.text = data['name'] ?? 'Cliente sem nome';
            _addressController.text = data['address'] ?? '';
            // Note: O backend não retorna 'phoneNumber'. Se tivesse, seria:
            // _phoneNumberController.text = data['phoneNumber'] ?? '';

            // TRAVA APENAS O CAMPO DE BUSCA (CPF/CNPJ)
            _isIdentifierReadOnly = true;
            // MANTÉM OS DEMAIS CAMPOS EDITÁVEIS (false)
            _isClientDataReadOnly = false;
          });
        }
        _showSnackBar(
            '✅ Cliente encontrado! Revise/atualize os dados.', Colors.green);
      } else if (response.statusCode == 401) {
        _showSnackBar(
            '🚫 Token de autenticação expirado. Faça o login novamente.',
            Colors.red);
      } else {
        // Cliente NÃO encontrado: limpa e mantém campos editáveis.
        if (mounted) {
          setState(() {
            _customerNameController.clear();
            _addressController.clear();
            _phoneNumberController.clear();
            _isClientDataReadOnly = false;
            _isIdentifierReadOnly = false;
          });
        }
        _showSnackBar(
            '⚠️ Cliente não encontrado. Preencha os dados para novo cadastro.',
            Colors.red);
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
    // 1. Validação do formulário Flutter (Título e Descrição)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Validação dos campos obrigatórios que não usam o validador nativo do FormField
    if (_selectedPriority == null) {
      _showSnackBar(
          '⚠️ A prioridade do agendamento é obrigatória.', Colors.red);
      return;
    }

    // --- LÓGICA DE VALIDAÇÃO CONDICIONAL ---
    // O Nome do Cliente é sempre obrigatório (mesmo que existente).
    if (_customerNameController.text.trim().isEmpty) {
      _showSnackBar('⚠️ O Nome do Cliente é obrigatório.', Colors.red);
      return;
    }

    // Endereço e Telefone SÃO obrigatórios SOMENTE se o cliente for NOVO.
    if (_clientId == null) {
      // Novo Cliente - Todos os dados são obrigatórios para a criação.
      if (_addressController.text.trim().isEmpty) {
        _showSnackBar(
            '⚠️ O Endereço de Instalação é obrigatório para novos clientes.',
            Colors.red);
        return;
      }
      if (_phoneNumberController.text.trim().isEmpty) {
        _showSnackBar(
            '⚠️ O Número de Contato do Cliente é obrigatório para novos clientes.',
            Colors.red);
        return;
      }
      // O CPF/CNPJ (identifier) também é obrigatório para novo cliente.
      if (_identifierController.text.trim().isEmpty) {
        _showSnackBar(
            '⚠️ O CPF/CNPJ é obrigatório para o cadastro de um novo cliente.',
            Colors.red);
        return;
      }
    }

    // 💡 CORREÇÃO CRÍTICA: Mapeamento da Prioridade para o formato da API (Ex: 'LOW', 'MEDIUM', 'HIGH')
    String apiPriority;
    switch (_selectedPriority) {
      case 'Baixa':
        apiPriority = 'LOW';
        break;
      case 'Média':
        apiPriority = 'MEDIUM';
        break;
      case 'Alta':
        apiPriority = 'HIGH';
        break;
      default:
        _showSnackBar('⚠️ Prioridade inválida.', Colors.red);
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
        'priority': apiPriority, // 🚀 Valor corrigido
        'requestedBy': widget.requestedByUserId,

        // Enviamos os dados do cliente (mesmo que vazios, se opcionais)
        'customerName': _customerNameController.text.trim(),
        'address': _addressController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'identifier': _identifierController.text.trim(),
      };

      // Adiciona 'clientId' SOMENTE se ele NÃO for nulo (cliente existente).
      if (_clientId != null) {
        body['clientId'] = _clientId;
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/ticket'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization':
                  'Bearer ${widget.authToken}', // 💡 Adicionado token
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        _formKey.currentState!.reset();
        _clearForm();
        _showSnackBar(
            '✅ Agendamento criado com sucesso! Pendente de aprovação do Admin.',
            Colors.green);
      } else if (response.statusCode == 401) {
        _showSnackBar(
            '🚫 Token de autenticação expirado. Faça o login novamente.',
            Colors.red);
      } else {
        final errorData = jsonDecode(response.body);
        String message = errorData['error'] ?? 'Falha ao criar agendamento.';
        _showSnackBar(
            '⚠️ Erro: $message (Código: ${response.statusCode})', Colors.red);
      }
    } catch (e) {
      _showSnackBar(
          '❌ Erro de conexão. Verifique a API/Internet.', Colors.deepOrange);
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
      // Reseta todas as flags de readOnly
      _isClientDataReadOnly = false;
      _isIdentifierReadOnly = false;
    });
    _titleController.clear();
    _customerNameController.clear();
    _addressController.clear();
    _descriptionController.clear();
    _identifierController.clear();
    _phoneNumberController.clear();
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

    // Define os textos dos labels condicionalmente
    final bool isNewClient = _clientId == null;
    final String nameLabel = isNewClient
        ? 'Nome Completo (Obrigatório)'
        : 'Nome Completo (Existente - Pode ser atualizado)';
    final String phoneLabel = isNewClient
        ? 'Número de Contato (Obrigatório para novo)'
        : 'Número de Contato (Existente - Opcional para atualização)';
    final String addressLabel = isNewClient
        ? 'Endereço de Instalação (Obrigatório para novo)'
        : 'Endereço de Instalação (Existente - Opcional para atualização)';

    // Label para o CPF/CNPJ
    final String identifierLabel = _isIdentifierReadOnly
        ? 'CPF/CNPJ (Cliente Encontrado)'
        : 'CPF/CNPJ (Obrigatório para novo)';

    return Scaffold(
      appBar: AppBar(
        // 2. TÍTULO COM GOOGLE FONTS
        title: Text('Novo Agendamento',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4, // Adiciona uma leve sombra para o AppBar
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
                'Buscar Cliente por Identificador',
                // 3. TÍTULO DE SEÇÃO COM GOOGLE FONTS
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.primaryColor),
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.text,
                      readOnly: _isIdentifierReadOnly,
                      decoration: _buildInputDecoration(
                              identifierLabel, LucideIcons.scan)
                          .copyWith(
                        filled: true, // Sempre preenchido para o estilo
                        // Destaca o campo de busca quando encontrado
                        fillColor: _isIdentifierReadOnly
                            ? Colors.lightGreen.shade50
                            : Colors.grey.shade50,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão de Busca
                  _isSearching
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(child: CircularProgressIndicator()))
                      : Container(
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(
                                16), // Arredonda o botão de ação
                          ),
                          child: IconButton(
                            icon: Icon(
                                _clientId != null
                                    ? LucideIcons.rotateCcw
                                    : LucideIcons.search,
                                size: 24,
                                color: Colors.white), // Ícone Branco
                            onPressed:
                                _clientId != null ? _clearForm : _searchClient,
                            tooltip: _clientId != null
                                ? 'Limpar e pesquisar outro'
                                : 'Buscar Cliente',
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 30),

              // --- 2. DADOS DO CLIENTE (MANUAL OU AUTO) ---
              Text(
                'Dados do Cliente',
                // 3. TÍTULO DE SEÇÃO COM GOOGLE FONTS
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.primaryColor),
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 15),

              // Campo Nome do Cliente (Sempre Obrigatório)
              TextFormField(
                controller: _customerNameController,
                readOnly: false, // Permitir edição sempre
                decoration:
                    _buildInputDecoration(nameLabel, LucideIcons.user).copyWith(
                  // Realça quando cliente existente
                  fillColor: _clientId != null
                      ? Colors.yellow.shade100
                      : Colors.grey.shade50,
                ),
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Campo Telefone (Obrigatório para novo, Opcional para existente)
              TextFormField(
                controller: _phoneNumberController,
                readOnly: false, // Permitir edição
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: _buildInputDecoration(phoneLabel, LucideIcons.phone)
                    .copyWith(
                  fillColor: _clientId != null
                      ? Colors.yellow.shade100
                      : Colors.grey.shade50,
                ),
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Campo Endereço (Obrigatório para novo, Opcional para existente)
              TextFormField(
                controller: _addressController,
                readOnly: false, // Permitir edição
                maxLines: 3,
                keyboardType: TextInputType.streetAddress,
                decoration:
                    _buildInputDecoration(addressLabel, LucideIcons.mapPin)
                        .copyWith(
                  fillColor: _clientId != null
                      ? Colors.yellow.shade100
                      : Colors.grey.shade50,
                ),
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // --- 3. DADOS DO TICKET ---
              Text(
                'Detalhes do Agendamento (Obrigatório)',
                // 3. TÍTULO DE SEÇÃO COM GOOGLE FONTS
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.primaryColor),
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 15),

              // Campo Título (OBRIGATÓRIO)
              TextFormField(
                controller: _titleController,
                decoration: _buildInputDecoration(
                    'Título do Serviço (Ex: Instalação Padrão)',
                    LucideIcons.tag),
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
                decoration: _buildInputDecoration(
                    'Prioridade do Serviço', LucideIcons.zap),
                value: _selectedPriority,
                isExpanded: true,
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

              // Campo Descrição/Detalhes (OBRIGATÓRIO)
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _buildInputDecoration(
                    'Descrição (Detalhes do Serviço)',
                    LucideIcons.clipboardList),
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
                  // 4. BOTÃO ARREDONDADO
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
                      )
                    : Text('Registrar Agendamento',
                        // 5. TEXTO DO BOTÃO COM GOOGLE FONTS
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
      // 6. CAMPOS SEMPRE PREENCHIDOS E COM FUNDO CLARO
      filled: true,
      fillColor: Colors.grey.shade50,
      prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
      // 7. BORDAS ARREDONDADAS (16px)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.all(15.0),
    );
  }
}
