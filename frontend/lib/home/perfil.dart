import 'package:flutter/material.dart';

import '../auth/login.dart';
import '../config/app_colors.dart';
import '../navigation/navegacao_principal.dart';
import '../services/auth_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';

class PerfilTela extends StatelessWidget {
  const PerfilTela({super.key});

  Future<void> sair(BuildContext context) async {
    await AuthService.sair();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginTela()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.usuarioLogado ?? {};
    final nome = usuario['nome']?.toString().trim() ?? '';
    final email = usuario['email']?.toString().trim() ?? '';
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Perfil'),
      bottomNavigationBar: BarraNavegacaoHome(
        currentIndex: 3,
        onTap: (indice) =>
            NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 3),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0x1A8F16D9),
              child: Text(
                inicial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              nome.isNotEmpty ? nome : 'Usuário',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email.isNotEmpty ? email : 'E-mail não informado',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 36),
            const Text(
              'Dados da conta',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
              ),
              title: const Text('Nome'),
              subtitle: Text(nome.isNotEmpty ? nome : 'Não informado'),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.email_outlined,
                color: AppColors.primary,
              ),
              title: const Text('E-mail'),
              subtitle: Text(email.isNotEmpty ? email : 'Não informado'),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => sair(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
