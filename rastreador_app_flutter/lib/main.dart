import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 🚨 IMPORTAÇÕES NECESSÁRIAS PARA O FLUXO COMPLETO
import 'create_ticket_screen.dart'; 
import 'techdashboardscreen.dart'; 
import 'admindashboardscreen.dart'; // <<< NOVO: Importação do Dashboard do Admin

// URL base do seu backend no Render
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rastreador App',
      theme: ThemeData(
        // Cor primária mais vívida para um visual moderno
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      // Começa o app na tela de login
      home: const LoginPage(),
    );
  }
}

// ===============================================
// TELA DE LOGIN 
// ===============================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para capturar o texto dos campos
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;

  /// Função assíncrona para realizar a chamada de API de login
  Future<void> _login() async {
    // 1. Inicia o carregamento
    setState(() {
      _isLoading = true;
    });

    final String email = _emailController.text.trim();
    final String senha = _passwordController.text;

    // 2. Validação local (usa SnackBar para feedback)
    if (email.isEmpty || senha.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, preencha todos os campos.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 3. Faz a requisição POST para a sua API
      final response = await http.post(
        Uri.parse('$API_BASE_URL/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'senha': senha,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // 4. Sucesso no login!
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // 🚨 NOVO: Lógica para extrair o role e token (que será adicionado no backend)
        final role = data['role'];
        final token = data['token'] ?? 'fake-token-do-db'; // Presume que o token virá, mas usa um fallback

        if (mounted) {
          // Usa pushReplacement para que o usuário não possa voltar para o login
          
          // >>> REDIRECIONAMENTO CORRIGIDO E ATUALIZADO <<<
          if (role == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDashboardScreen(authToken: token), // Redireciona para o Admin Dashboard
              ),
            );
          } else {
            // Vendedor ('seller') e Técnico ('tech') vão para a HomeScreen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen(userData: data)),
            );
          }
        }

      } else {
        // 5. Falha no login (ex: credenciais inválidas)
        try {
            final errorData = jsonDecode(response.body);
            final message = errorData['error'] ?? 'Erro de login. Verifique as credenciais.'; 
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            }
        } catch (_) {
              // Caso a resposta não seja JSON (erros genéricos ou servidor retornando HTML)
              if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('Erro na API. O servidor pode estar inativo ou o endpoint está incorreto.'),
                   backgroundColor: Colors.deepOrange,
                 ),
               );
              }
        }
      }
    } catch (e) {
      // 6. Erro de rede, timeout, ou servidor
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro de conexão. Verifique sua rede e a API.'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } finally {
      // 7. Finaliza o carregamento
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
        title: const Text('Rastreador App'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
      ),
      // O SingleChildScrollView evita que o teclado cause overflow/quebra na tela
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Título ou Logo
              Text(
                'Bem-Vindo',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 40),

              // Campo de E-mail (Com UX melhorado)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder( // Borda com a cor do tema
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Campo de Senha (Com UX melhorado)
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Botão de Login (Com Loading integrado)
              ElevatedButton(
                // Desabilita o botão se estiver carregando
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor, 
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50), // Botão de largura total
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const SizedBox( // Indicador de carregamento
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'Entrar', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
              ),
              
              const SizedBox(height: 20),
              
            ],
          ),
        ),
      ),
    );
  }
}

// ===============================================
// TELA DE HOME (MENU PRINCIPAL)
// ===============================================

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    // Extração dos dados do usuário logado
    String userName = userData['name'] ?? 'Usuário Desconhecido';
    String userRole = userData['role'] ?? 'Sem Cargo';
    // Garante que userId seja um inteiro, que é o esperado para a rota
    int userId = (userData['id'] is int) ? userData['id'] : int.tryParse(userData['id'].toString()) ?? 0;
    String userEmail = userData['email'] ?? 'Sem E-mail';
    String rawData = jsonEncode(userData); // Para mostrar no debug
    
    // 🚨 NOVO: Extrai o token, pois o AdminDashboard precisa dele.
    // Como a HomeScreen recebe o Map completo, o token precisa vir do backend no /login.
    String authToken = userData['token'] ?? 'fake-token-do-db'; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-Vindo(a)'),
        automaticallyImplyLeading: false, 
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          // Botão de Sair que retorna para a tela de Login
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (Route<dynamic> route) => false, // Remove todas as rotas anteriores
              );
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Olá, $userName!', 
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: Theme.of(context).primaryColor
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text('Você está logado como ${userRole.toUpperCase()}.', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 30),

              // 🚨 BOTÃO DE CRIAÇÃO DE TICKET (VENDEDOR/ADMIN)
              if (userRole == 'admin' || userRole == 'seller')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_to_photos_rounded),
                    label: const Text('Novo Agendamento', style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateTicketScreen(
                            requestedByUserId: userId, // Passa o ID do Vendedor/Admin
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                

              // 🚨 BOTÃO DE VISUALIZAÇÃO DE CHAMADOS (TÉCNICO)
              if (userRole == 'tech')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.build_circle),
                    label: const Text('Meus Chamados (Técnico)', style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      // >>> NAVEGAÇÃO CORRIGIDA AQUI <<<
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TechDashboardScreen(
                            techId: userId, // Passa o ID do Técnico
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                
              // 🚨 BOTÃO DO ADMIN - AGORA FUNCIONAL
              if (userRole == 'admin')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.security),
                    label: const Text('Gestão de Chamados (Admin)', style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      // >>> AÇÃO ATUALIZADA PARA IR PARA A TELA REAL <<<
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminDashboardScreen(
                            authToken: authToken, // Passa o token para buscar todos os tickets
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                
              const SizedBox(height: 50),

              // Detalhes e Debug
              const Text('Detalhes do Login:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('E-mail: $userEmail'),
              Text('ID: $userId'),
              
              const SizedBox(height: 30),
              
              const Text('Raw Data (Debug):', style: TextStyle(fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  rawData,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
