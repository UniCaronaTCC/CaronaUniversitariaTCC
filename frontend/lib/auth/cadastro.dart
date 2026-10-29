import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../widgets/auth_secundario.dart';
import '../services/auth_service.dart';
import '../utils/validacao_email.dart';
import '../utils/validacao_senha.dart';
import 'confirmar_email.dart';
import 'login.dart';

class CadastroTela extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(
    String nome,
    String email,
    String senha,
  )?
  cadastrar;

  const CadastroTela({super.key, this.cadastrar});

  @override
  State<CadastroTela> createState() => _CadastroTelaState();
}

class _CadastroTelaState extends State<CadastroTela> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool carregando = false;
  bool _senhaOculta = true;

  bool get _telaAtiva => mounted && ModalRoute.of(context)?.isCurrent == true;

  void _irParaLogin() {
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

  Future<void> fazerCadastro() async {
    if (carregando || !_telaAtiva) return;
    if (nomeController.text.trim().isEmpty) {
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

    if (!ValidacaoEmail.ehValido(emailController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(ValidacaoEmail.mensagem)));
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

    final nome = nomeController.text;
    final email = emailController.text.trim().toLowerCase();
    final senha = senhaController.text;

    FocusScope.of(context).unfocus();
    setState(() {
      carregando = true;
    });

    try {
      final resultado = await (widget.cadastrar ?? AuthService.fazerCadastro)(
        nome,
        email,
        senha,
      );

      if (!mounted || !_telaAtiva) return;

      if (resultado['sucesso'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado['dados']['mensagem'] ??
                  'Cadastro realizado com sucesso',
            ),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmarEmailTela(email: email),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['mensagem']?.toString() ?? 'Erro ao cadastrar',
          ),
        ),
      );
    } catch (_) {
      if (!mounted || !_telaAtiva) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível criar sua conta. Tente novamente'),
        ),
      );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TelaAuthSecundaria(
    identificador: 'cadastro',
    titulo: 'Crie sua conta',
    subtitulo: 'Sua próxima carona começa aqui.',
    onVoltar: carregando ? null : _irParaLogin,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campoCadastro(
          id: 'nome',
          rotulo: 'Nome',
          hint: 'Seu nome',
          icone: Icons.person_outline_rounded,
          controller: nomeController,
        ),
        const SizedBox(height: 18),
        _campoCadastro(
          id: 'email',
          rotulo: 'E-mail',
          hint: 'Seu e-mail',
          icone: Icons.mail_outline_rounded,
          controller: emailController,
        ),
        const SizedBox(height: 18),
        _campoCadastro(
          id: 'senha',
          rotulo: 'Senha',
          hint: 'Crie uma senha',
          icone: Icons.lock_outline_rounded,
          controller: senhaController,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pelo menos 8 caracteres, com letras e números.',
          style: TextStyle(color: Color(0xFF666879), fontSize: 13),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const ValueKey('criar-conta-cadastro'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.65),
            disabledForegroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: carregando ? null : fazerCadastro,
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
                  carregando ? 'Criando conta...' : 'Criar conta',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            const Text(
              'Já tem uma conta?',
              style: TextStyle(color: Color(0xFF666879), fontSize: 14),
            ),
            TextButton(
              key: const ValueKey('entrar-cadastro'),
              onPressed: carregando ? null : _irParaLogin,
              child: Text(
                'Entrar',
                style: TextStyle(
                  color: carregando ? Colors.black38 : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _campoCadastro({
    required String id,
    required String rotulo,
    required String hint,
    required IconData icone,
    required TextEditingController controller,
  }) {
    final senha = id == 'senha';
    final nome = id == 'nome';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          rotulo,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: ValueKey('$id-cadastro'),
          controller: controller,
          enabled: !carregando,
          obscureText: senha && _senhaOculta,
          keyboardType: senha
              ? TextInputType.visiblePassword
              : nome
              ? TextInputType.name
              : TextInputType.emailAddress,
          textCapitalization: nome
              ? TextCapitalization.sentences
              : TextCapitalization.none,
          textInputAction: senha ? TextInputAction.done : TextInputAction.next,
          autofillHints: [
            senha
                ? AutofillHints.newPassword
                : nome
                ? AutofillHints.name
                : AutofillHints.email,
          ],
          autocorrect: nome,
          enableSuggestions: !senha,
          onSubmitted: senha ? (_) => fazerCadastro() : null,
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
}
