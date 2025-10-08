import 'dart:convert';
import 'dart:ui'; // Necessário para o BackdropFilter (Efeito de Vidro Fosco)
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
            // Mantendo o border radius mais arredondado do Cód. 1 para o tema geral
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
            ),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// =====================================================
// 🧭 TELA DE LOGIN (COM VISUAL MELHORADO DO CÓDIGO 1)
// =====================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  
  // Animações para o efeito de entrada do formulário
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
          // Redireciona para a HomeScreen (Vendedor/Técnico)
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
          // 🌄 Imagem de fundo com overlay escuro
          Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.45),
            colorBlendMode: BlendMode.darken,
          ),

          // ✨ Formulário com efeito de vidro (frosted glass) e animação
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter( // Efeito de Vidro Fosco
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Título com sombra
                            Text(
                              'Bem-vindo',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: trackerYellow,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black.withOpacity(0.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Campo E-mail com preenchimento
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                labelText: 'E-mail',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Campo Senha com preenchimento
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Botão Entrar
                            ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: trackerBlue,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
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
                  ),
                ),
              ),
            ),
          ),

          // 🖋️ Assinatura fixa (Posicionado no Stack)
          const Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
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
          ),
        ],
      ),
    );
  }
}

// =====================================================
// 🏠 HOME SCREEN (do Código 2, com tema visual do Cód. 1)
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
          // Fundo
          Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.3),
            colorBlendMode: BlendMode.darken,
          ),
          // Conteúdo central
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
                      shadows: [
                        // Adicionando sombra do Cód. 1 para realçar o texto
                        Shadow(
                          blurRadius: 5,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
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
                  // 🖋️ Assinatura na home
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