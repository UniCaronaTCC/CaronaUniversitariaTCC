import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../services/email_verificacao_service.dart';
import '../utils/validacao_email.dart';
import '../utils/validacao_senha.dart';
import '../widgets/auth_widgets.dart';
import 'login.dart';

typedef SolicitarCodigoSenha =
    Future<Map<String, dynamic>> Function(String email);
typedef RedefinirSenha =
    Future<Map<String, dynamic>> Function(
      String email,
      String codigo,
      String novaSenha,
    );

class EsqueciSenhaTela extends StatefulWidget {
  final SolicitarCodigoSenha? solicitarCodigo;
  final RedefinirSenha? redefinirSenha;

  const EsqueciSenhaTela({
    super.key,
    this.solicitarCodigo,
    this.redefinirSenha,
  });

  @override
  State<EsqueciSenhaTela> createState() => _EsqueciSenhaTelaState();
}

class _EsqueciSenhaTelaState extends State<EsqueciSenhaTela> {
  final emailController = TextEditingController();
  final codigoController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool codigoEnviado = false;
  bool carregando = false;

  Future<void> solicitarCodigo() async {
    final email = emailController.text.trim();

    if (!ValidacaoEmail.ehValido(email)) {
      mostrarMensagem(ValidacaoEmail.mensagem);
      return;
    }

    setState(() => carregando = true);

    final enviar =
        widget.solicitarCodigo ??
        EmailVerificacaoService.solicitarRedefinicaoSenha;
    final resultado = await enviar(email);

    if (!mounted) return;

    setState(() {
      carregando = false;
      if (resultado['sucesso'] == true) {
        codigoEnviado = true;
      }
    });

    mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Não foi possível enviar o código',
    );
  }

  Future<void> redefinirSenha() async {
    final codigo = codigoController.text.trim();
    final senha = senhaController.text;

    if (!RegExp(r'^\d{8}$').hasMatch(codigo)) {
      mostrarMensagem('Informe o código de 8 dígitos');
      return;
    }

    if (!ValidacaoSenha.ehValida(senha)) {
      mostrarMensagem(ValidacaoSenha.mensagem);
      return;
    }

    if (senha != confirmarSenhaController.text) {
      mostrarMensagem('As senhas não são iguais');
      return;
    }

    setState(() => carregando = true);

    final enviar =
        widget.redefinirSenha ?? EmailVerificacaoService.redefinirSenha;
    final resultado = await enviar(emailController.text.trim(), codigo, senha);

    if (!mounted) return;

    setState(() => carregando = false);

    mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Não foi possível redefinir a senha',
    );

    if (resultado['sucesso'] == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginTela()),
        (_) => false,
      );
    }
  }

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  void dispose() {
    emailController.dispose();
    codigoController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AuthCard(
              children: [
                const Icon(Icons.lock_reset, color: Colors.white, size: 46),
                const SizedBox(height: 14),
                const Text(
                  'REDEFINIR SENHA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  codigoEnviado
                      ? 'Digite o código enviado para\n${emailController.text.trim()}'
                      : 'Informe seu e-mail para receber um código',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 28),
                if (!codigoEnviado) ...[
                  AuthCampoTexto(
                    hint: 'E-mail',
                    icone: Icons.email_outlined,
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 22),
                  AuthBotaoPrincipal(
                    texto: carregando ? 'ENVIANDO...' : 'ENVIAR CÓDIGO',
                    onPressed: carregando ? null : solicitarCodigo,
                  ),
                ] else ...[
                  TextField(
                    controller: codigoController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '00000000',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthCampoTexto(
                    hint: 'Nova senha',
                    icone: Icons.lock_outline,
                    controller: senhaController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  AuthCampoTexto(
                    hint: 'Confirmar nova senha',
                    icone: Icons.lock_outline,
                    controller: confirmarSenhaController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 22),
                  AuthBotaoPrincipal(
                    texto: carregando ? 'SALVANDO...' : 'SALVAR NOVA SENHA',
                    onPressed: carregando ? null : redefinirSenha,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: carregando ? null : solicitarCodigo,
                    child: const Text(
                      'Reenviar código',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
