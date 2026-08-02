import 'package:flutter/material.dart';
import 'package:uni_carona/mapa/screens/mapa_screen.dart';

import 'auth/login.dart';
import 'config/app_theme.dart';
import 'home/minhas_caronas.dart';
import 'home/perfil.dart';
import 'home/tela_inicial.dart';
import 'navigation/navegacao_principal.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.carregarSessao();

  final nomeUsuario = AuthService.usuarioLogado?['nome']?.toString() ?? '';

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthService.estaLogado
          ? TelaInicial(nomeUsuario: nomeUsuario)
          : const LoginTela(),
      routes: {
        NavegacaoPrincipal.rotaCaronas: (_) => const MinhasCaronasTela(),
        NavegacaoPrincipal.rotaPerfil: (_) => const PerfilTela(),
      },
    ),
  );
}
