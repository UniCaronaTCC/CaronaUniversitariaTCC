import 'package:flutter/material.dart';

import 'auth/login.dart';
import 'config/app_theme.dart';
import 'home/conversas.dart';
import 'home/minhas_caronas.dart';
import 'home/perfil.dart';
import 'home/tela_inicial.dart';
import 'inicializacao/tela_abertura.dart';
import 'navigation/navegacao_principal.dart';
import 'services/auth_service.dart';
import 'services/supabase_auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BuscaEuApp());
}

Future<void> _inicializarServicos() async {
  await SupabaseAuthService.inicializar();
  await AuthService.carregarSessao();
}

class BuscaEuApp extends StatelessWidget {
  final Future<void> Function()? inicializar;

  const BuscaEuApp({super.key, this.inicializar});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BuscaEu',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: TelaAbertura(
      inicializar: inicializar ?? _inicializarServicos,
      construirDestino: (_) => AuthService.estaLogado
          ? TelaInicial(
              nomeUsuario: AuthService.usuarioLogado?['nome']?.toString() ?? '',
            )
          : const LoginTela(),
    ),
    routes: {
      NavegacaoPrincipal.rotaChat: (_) => const ConversasTela(),
      NavegacaoPrincipal.rotaCaronas: (_) => const MinhasCaronasTela(),
      NavegacaoPrincipal.rotaPerfil: (_) => const PerfilTela(),
    },
  );
}
