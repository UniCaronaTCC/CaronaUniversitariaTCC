import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/auth_service.dart';
import '../utils/validacao_senha.dart';
import '../widgets/auth_widgets.dart';
import 'login.dart';

class CadastroTela extends StatefulWidget {
  const CadastroTela({super.key});

  @override
  State<CadastroTela> createState() => _CadastroTelaState();
}

class _CadastroTelaState extends State<CadastroTela> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool carregando = false;

  Future<void> fazerCadastro() async {
    if (nomeController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe seu nome')));
      return;
    }

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

    if (!ValidacaoSenha.ehValida(senhaController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(ValidacaoSenha.mensagem)));
      return;
    }

    setState(() {
      carregando = true;
    });

    final resultado = await AuthService.fazerCadastro(
      nomeController.text,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['dados']['mensagem'] ?? 'Cadastro realizado com sucesso',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginTela()),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(resultado['mensagem'])));
  }

  @override
  void dispose() {
    nomeController.dispose();
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
                  'CADASTRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Crie sua conta',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 36),
                AuthCampoTexto(
                  hint: 'Nome',
                  icone: Icons.person,
                  controller: nomeController,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Use no mínimo 8 caracteres, com letras e números.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                AuthBotaoPrincipal(
                  texto: carregando ? 'CADASTRANDO...' : 'CADASTRAR',
                  onPressed: carregando ? null : fazerCadastro,
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginTela(),
                      ),
                    );
                  },
                  child: const Text(
                    'Já tem uma conta? Entrar',
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
