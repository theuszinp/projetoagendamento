import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_state.dart';
import '../main.dart' show LoginPage;
import '../ui/shells/admin_shell.dart';
import '../ui/shells/seller_shell.dart';
import '../ui/shells/tech_shell.dart';
import '../ui/splash_screen.dart';

GoRouter createRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth.listenable,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),

      /// Shells por role
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminShell(),
      ),
      GoRoute(
        path: '/seller',
        builder: (context, state) => const SellerShell(),
      ),
      GoRoute(
        path: '/tech',
        builder: (context, state) => const TechShell(),
      ),
    ],
    redirect: (context, state) {
      final auth = context.read<AuthState>();

      final goingToSplash = state.uri.toString() == '/splash';
      if (auth.isBootstrapping) return goingToSplash ? null : '/splash';

      final loggedIn = auth.isAuthenticated;
      final isLogin = state.uri.toString() == '/login';

      if (!loggedIn) return isLogin ? null : '/login';
      if (isLogin || goingToSplash) {
        // manda para home baseada no role
        if (auth.role == 'admin') return '/admin';
        if (auth.role == 'tech' || auth.role == 'tecnico') return '/tech';
        return '/seller';
      }

      // se estiver logado, bloqueia acesso a rotas de outro role
      final loc = state.uri.toString();
      if (auth.role == 'admin' && !loc.startsWith('/admin')) return '/admin';
      if ((auth.role == 'tech' || auth.role == 'tecnico') && !loc.startsWith('/tech')) return '/tech';
      if ((auth.role == 'seller' || auth.role == 'vendedor') && !loc.startsWith('/seller')) return '/seller';

      return null;
    },
  );
}
