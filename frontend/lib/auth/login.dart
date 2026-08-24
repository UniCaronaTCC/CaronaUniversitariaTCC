import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../home/tela_inicial.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'cadastro.dart';
import 'esqueci_senha.dart';

class LoginTela extends StatefulWidget {
  const LoginTela({super.key});

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool carregando = false;

  Future<void> fazerLogin() async {
    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe seu e-mail')));
      return;
    }

    if (senhaController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe sua senha')));
      return;
    }

    setState(() {
      carregando = true;
    });

    final resultado = await AuthService.fazerLogin(
      emailController.text,
      senhaController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      carregando = false;
    });

    if (resultado['sucesso'] == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado['dados']['mensagem'])));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TelaInicial(
            nomeUsuario: resultado['dados']['usuario']['nome'].toString(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado['mensagem'])));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AuthCard(
              children: [
                const Text(
                  'ENTRAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bem-vindo ao app',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 36),
                AuthCampoTexto(
                  hint: 'E-mail',
                  icone: Icons.email,
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                AuthCampoTexto(
                  hint: 'Senha',
                  icone: Icons.lock,
                  controller: senhaController,
                  obscureText: true,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EsqueciSenhaTela(),
                        ),
                      );
                    },
                    child: const Text(
                      'Esqueceu sua senha?',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AuthBotaoPrincipal(
                  texto: carregando ? 'ENTRANDO...' : 'ENTRAR',
                  onPressed: carregando ? null : fazerLogin,
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CadastroTela(),
                      ),
                    );
                  },
                  child: const Text(
                    'Não tem uma conta? Cadastre-se',
                    style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
