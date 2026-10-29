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
  String? _emailRecuperacao;
  String? _erroEmail;

  bool get _telaAtiva => mounted && ModalRoute.of(context)?.isCurrent == true;

  void _voltarParaLogin() {
    if (carregando || !_telaAtiva) return;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginTela()),
      );
    }
  }

  Future<void> solicitarCodigo() async {
    if (carregando || !_telaAtiva) return;
    final email = _emailRecuperacao ?? emailController.text.trim();

    if (!ValidacaoEmail.ehValido(email)) {
      setState(() => _erroEmail = ValidacaoEmail.mensagem);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      carregando = true;
      _erroEmail = null;
    });
    try {
      final enviar =
          widget.solicitarCodigo ??
          EmailVerificacaoService.solicitarRedefinicaoSenha;
      final resultado = await enviar(email);
      if (!mounted || !_telaAtiva) return;
      if (resultado['sucesso'] == true) {
        setState(() {
          _emailRecuperacao = email;
          codigoEnviado = true;
        });
        mostrarMensagem(
          resultado['mensagem']?.toString() ??
              'Código enviado para o seu e-mail',
        );
      } else {
        _mostrarFalhaEnvio(
          resultado['mensagem']?.toString() ??
              'Não foi possível enviar o código',
        );
      }
    } catch (_) {
      if (!mounted || !_telaAtiva) return;
      _mostrarFalhaEnvio('Não foi possível enviar o código. Tente novamente');
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  void _mostrarFalhaEnvio(String mensagem) {
    if (codigoEnviado) {
      mostrarMensagem(mensagem);
    } else {
      setState(() => _erroEmail = mensagem);
    }
  }

  Future<void> redefinirSenha() async {
    if (carregando || !_telaAtiva || !codigoEnviado) return;
    final email = _emailRecuperacao;
    if (email == null) return;
    final codigo = codigoController.text.trim();
    final senha = senhaController.text;

    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      mostrarMensagem('Informe o código de 6 dígitos');
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

    FocusScope.of(context).unfocus();
    setState(() => carregando = true);
    try {
      final enviar =
          widget.redefinirSenha ?? EmailVerificacaoService.redefinirSenha;
      final resultado = await enviar(email, codigo, senha);
      if (!mounted || !_telaAtiva) return;

      mostrarMensagem(
        resultado['mensagem']?.toString() ??
            (resultado['sucesso'] == true
                ? 'Senha redefinida com sucesso'
                : 'Não foi possível redefinir a senha'),
      );

      if (resultado['sucesso'] == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginTela()),
          (_) => false,
        );
      }
    } catch (_) {
      if (!mounted || !_telaAtiva) return;
      mostrarMensagem('Não foi possível redefinir a senha. Tente novamente');
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  void mostrarMensagem(String mensagem) {
    if (!_telaAtiva) return;
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
    if (!codigoEnviado) return _solicitarRecuperacao();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar para o login',
          onPressed: carregando ? null : _voltarParaLogin,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AbsorbPointer(
              absorbing: carregando,
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
                    'Digite o código enviado para\n$_emailRecuperacao',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: codigoController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _solicitarRecuperacao() => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        key: const ValueKey('voltar-recuperacao'),
        tooltip: 'Voltar para o login',
        onPressed: carregando ? null : _voltarParaLogin,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/imagens/icone_buscaeu.png',
                        key: const ValueKey('logo-recuperacao'),
                        width: 80,
                        height: 80,
                        semanticLabel: 'Logo BuscaEu',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Busca',
                          style: TextStyle(color: AppColors.text),
                        ),
                        TextSpan(
                          text: 'Eu',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    semanticsLabel: 'BuscaEu',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Esqueceu sua senha?',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Informe seu e-mail para receber um código de recuperação.',
                    style: TextStyle(color: Color(0xFF666879), fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'E-mail',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('email-recuperacao'),
                    controller: emailController,
                    enabled: !carregando,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => solicitarCodigo(),
                    onChanged: (_) {
                      if (_erroEmail != null) {
                        setState(() => _erroEmail = null);
                      }
                    },
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Seu e-mail',
                      hintStyle: const TextStyle(color: Color(0xFF727587)),
                      constraints: const BoxConstraints(minHeight: 56),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F6F9),
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        color: Color(0xFF666879),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _erroEmail == null
                              ? const Color(0xFFD1D2DC)
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _erroEmail == null
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.error,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  if (_erroEmail != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _erroEmail!,
                        key: const ValueKey('erro-recuperacao'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const ValueKey('solicitar-codigo-senha'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.65,
                      ),
                      disabledForegroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    onPressed: carregando ? null : solicitarCodigo,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (carregando) ...[
                          const ExcludeSemantics(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Flexible(
                          child: Text(
                            carregando ? 'Enviando...' : 'Enviar código',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    key: const ValueKey('login-recuperacao'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    onPressed: carregando ? null : _voltarParaLogin,
                    child: const Text(
                      'Voltar para o login',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
