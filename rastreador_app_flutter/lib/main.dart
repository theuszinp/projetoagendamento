import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 🧩 Importações de telas
import 'create_ticket_screen.dart';
import 'techdashboardscreen.dart';
import 'admindashboardscreen.dart';
import 'SellerTicketListScreen.dart';

// 🌐 URL base do backend
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

// 🎨 Cores oficiais da TrackerCarsat
const Color trackerBlue = Color(0xFF322C8E);
const Color trackerYellow = Color(0xFFFFD700);

void main() {
  runApp(const RastreadorApp());
}

class RastreadorApp extends StatelessWidget {
  const RastreadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackerCarsat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: trackerBlue,
          primary: trackerBlue,
          secondary: trackerYellow,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: trackerBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// =====================================================
// 🧭 TELA DE LOGIN
// =====================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final String email = _emailController.text.trim();
    final String senha = _passwordController.text;

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos.'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final role = (data['role'] ?? '').toString().toLowerCase();
        final token = data['token'] ?? 'fake-token';
        final userId = int.tryParse(data['id'].toString()) ?? 0;

        // Redireciona conforme a função do usuário
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AdminDashboardScreen(authToken: token, userId: userId),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HomeScreen(userData: data, authToken: token),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        final message = errorData['error'] ?? 'Erro ao fazer login.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro de conexão. Verifique sua internet.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌄 Imagem de fundo
          Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.4),
            colorBlendMode: BlendMode.darken,
          ),

          // 🧱 Formulário centralizado
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: Colors.white.withOpacity(0.9),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bem-vindo',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: trackerYellow,
                            ),
                          ),
                          const SizedBox(height: 30),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: trackerBlue,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // 🖋️ Assinatura fixa
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.code, color: Colors.white70, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Desenvolvido por theusdev',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// 🏠 HOME SCREEN (Vendedor / Técnico)
// =====================================================

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String authToken;

  const HomeScreen({
    super.key,
    required this.userData,
    required this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    final String userName = userData['name'] ?? 'Usuário';
    final String userRole = (userData['role'] ?? '').toString().toLowerCase();
    final int userId = int.tryParse(userData['id'].toString()) ?? 0;

    final List<Widget> actionButtons = [];

    // 🔹 Botões do vendedor
    if (userRole == 'seller' || userRole == 'vendedor') {
      actionButtons.addAll([
        ElevatedButton.icon(
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Novo Agendamento'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTicketScreen(requestedByUserId: userId),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('Status dos Meus Agendamentos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SellerTicketListScreen(authToken: authToken, userId: userId),
              ),
            );
          },
        ),
      ]);
    }

    // 🔧 Botão do técnico
    if (userRole == 'tech' || userRole == 'técnico') {
      actionButtons.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.build_circle),
          label: const Text('Meus Chamados (Técnico)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: trackerBlue,
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TechDashboardScreen(techId: userId, authToken: authToken),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Principal'),
        backgroundColor: trackerBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.3),
            colorBlendMode: BlendMode.darken,
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Bem-vindo(a), $userName!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: trackerYellow,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cargo: ${userRole.toUpperCase()}',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 30),
                  ...actionButtons,
                  const SizedBox(height: 40),
                  // 🖋️ Assinatura na home também
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.code, color: Colors.white70, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Desenvolvido por theusdev',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
