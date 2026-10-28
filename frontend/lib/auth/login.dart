import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../home/tela_inicial.dart';
import '../services/auth_service.dart';
import 'cadastro.dart';
import 'esqueci_senha.dart';

class LoginTela extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String email, String senha)?
  autenticar;

  const LoginTela({super.key, this.autenticar});

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool carregando = false;
  bool _senhaOculta = true;

  bool get _telaAtiva => mounted && ModalRoute.of(context)?.isCurrent == true;

  void _abrirTela(WidgetBuilder builder) {
    if (carregando || !_telaAtiva) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  Future<void> fazerLogin() async {
    if (carregando || !_telaAtiva) return;
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

    FocusScope.of(context).unfocus();
    setState(() {
      carregando = true;
    });

    try {
      final resultado = await (widget.autenticar ?? AuthService.fazerLogin)(
        emailController.text.trim(),
        senhaController.text,
      );

      if (!mounted || !_telaAtiva) return;

      if (resultado['sucesso'] == true) {
        final mensagem = resultado['dados']['mensagem'] as String;
        final nomeUsuario = resultado['dados']['usuario']['nome'].toString();
        TextInput.finishAutofillContext(shouldSave: true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagem)));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TelaInicial(nomeUsuario: nomeUsuario),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado['mensagem']?.toString() ??
                  'Não foi possível entrar. Tente novamente',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted || !_telaAtiva) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível entrar. Tente novamente'),
        ),
      );
    } finally {
      if (mounted) setState(() => carregando = false);
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 64).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
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
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/imagens/icone_buscaeu.png',
                              key: const ValueKey('logo-login'),
                              width: 128,
                              height: 128,
                              semanticLabel: 'Logo BuscaEu',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          key: ValueKey('marca-login'),
                          semanticsLabel: 'BuscaEu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Entre na sua conta',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Bom ter você por aqui.',
                          style: TextStyle(
                            color: Color(0xFF666879),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _campoLogin(
                          rotulo: 'E-mail',
                          hint: 'Seu e-mail',
                          icone: Icons.mail_outline_rounded,
                          controller: emailController,
                        ),
                        const SizedBox(height: 20),
                        _campoLogin(
                          rotulo: 'Senha',
                          hint: 'Sua senha',
                          icone: Icons.lock_outline_rounded,
                          controller: senhaController,
                          senha: true,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: carregando
                                ? null
                                : () => _abrirTela(
                                    (_) => const EsqueciSenhaTela(),
                                  ),
                            child: Text(
                              'Esqueceu sua senha?',
                              style: TextStyle(
                                color: carregando
                                    ? Colors.black38
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          key: const ValueKey('entrar-login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary
                                .withValues(alpha: 0.65),
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
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          onPressed: carregando ? null : fazerLogin,
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
                                  carregando ? 'Entrando...' : 'Entrar',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            const Text(
                              'Ainda não tem uma conta?',
                              style: TextStyle(
                                color: Color(0xFF666879),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: carregando
                                  ? null
                                  : () =>
                                        _abrirTela((_) => const CadastroTela()),
                              child: Text(
                                'Criar conta',
                                style: TextStyle(
                                  color: carregando
                                      ? Colors.black38
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _campoLogin({
    required String rotulo,
    required String hint,
    required IconData icone,
    required TextEditingController controller,
    bool senha = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        rotulo,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        key: ValueKey(senha ? 'senha-login' : 'email-login'),
        controller: controller,
        enabled: !carregando,
        obscureText: senha && _senhaOculta,
        keyboardType: senha
            ? TextInputType.visiblePassword
            : TextInputType.emailAddress,
        textInputAction: senha ? TextInputAction.done : TextInputAction.next,
        autofillHints: [
          senha ? AutofillHints.password : AutofillHints.username,
        ],
        autocorrect: false,
        enableSuggestions: !senha,
        onSubmitted: senha ? (_) => fazerLogin() : null,
        style: const TextStyle(color: AppColors.text, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF727587)),
          constraints: const BoxConstraints(minHeight: 56),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          filled: true,
          fillColor: const Color(0xFFF6F6F9),
          prefixIcon: Icon(icone, color: const Color(0xFF666879)),
          suffixIcon: senha
              ? IconButton(
                  tooltip: _senhaOculta ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: carregando
                      ? null
                      : () => setState(() => _senhaOculta = !_senhaOculta),
                  icon: Icon(
                    _senhaOculta
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF666879),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D2DC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D2DC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    ],
  );
}
