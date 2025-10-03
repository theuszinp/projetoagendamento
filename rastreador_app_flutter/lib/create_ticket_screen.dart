import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  
  // Controladores
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _trackerIdController = TextEditingController(); 
  
  bool _isLoading = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _trackerIdController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    // 1. Validação do formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/tickets'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // Campos obrigatórios
          'customer_name': _customerNameController.text.trim(),
          'customer_address': _addressController.text.trim(),
          'description': _descriptionController.text.trim(),
          'requested_by': widget.requestedByUserId, // ID do usuário logado (Vendedor)

          // Campos opcionais
          'tracker_id': _trackerIdController.text.trim().isEmpty 
                        ? null 
                        : _trackerIdController.text.trim(),
          'assigned_to': null, // O Admin fará a atribuição depois
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        // Sucesso: Limpa o formulário e mostra mensagem
        _formKey.currentState!.reset();
        _customerNameController.clear();
        _addressController.clear();
        _descriptionController.clear();
        _trackerIdController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Agendamento criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          // Opcional: Navegar de volta para a lista (futura)
        }
      } else {
        // Erro retornado pela API
        final errorData = jsonDecode(response.body);
        String message = errorData['error'] ?? 'Falha ao criar agendamento.';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Erro: $message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Erro de rede/conexão
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro de conexão. Verifique a API/Internet.'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Agendamento'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ... Campos de Formulário (Mantidos como no código anterior) ...
              
              // Título
              Text(
                'Dados do Cliente',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(),
              const SizedBox(height: 15),

              // Campo Nome do Cliente
              TextFormField(
                controller: _customerNameController,
                decoration: _buildInputDecoration('Nome Completo', Icons.person),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'O nome do cliente é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Campo Endereço
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                keyboardType: TextInputType.streetAddress,
                decoration: _buildInputDecoration('Endereço de Instalação', Icons.location_on),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'O endereço é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Campo Descrição/Detalhes
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _buildInputDecoration('Descrição (Detalhes do Serviço)', Icons.description),
              ),
              const SizedBox(height: 15),
              
              // Campo ID Rastreador (Opcional)
              TextFormField(
                controller: _trackerIdController,
                keyboardType: TextInputType.text,
                decoration: _buildInputDecoration('ID Rastreador (IMEI ou Código)', Icons.devices),
              ),
              const SizedBox(height: 30),

              // Botão de Envio (Com Loading Integrado)
              ElevatedButton(
                onPressed: _isLoading ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
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