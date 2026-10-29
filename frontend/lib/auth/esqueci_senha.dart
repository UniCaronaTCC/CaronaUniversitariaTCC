import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../services/email_verificacao_service.dart';
import '../utils/validacao_email.dart';
import '../utils/validacao_senha.dart';
import '../widgets/auth_secundario.dart';
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
  bool _novaSenhaOculta = true;
  bool _confirmacaoOculta = true;

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
  Widget build(BuildContext context) =>
      codigoEnviado ? _redefinirSenha() : _solicitarRecuperacao();

  Widget _solicitarRecuperacao() => TelaAuthSecundaria(
    identificador: 'recuperacao',
    titulo: 'Esqueceu sua senha?',
    subtitulo: 'Informe seu e-mail para receber um código de recuperação.',
    onVoltar: carregando ? null : _voltarParaLogin,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          onPressed: carregando ? null : _voltarParaLogin,
          child: const Text('Voltar para o login', textAlign: TextAlign.center),
        ),
      ],
    ),
  );

  Widget _redefinirSenha() => TelaAuthSecundaria(
    identificador: 'redefinicao',
    titulo: 'Crie uma nova senha',
    subtitulo: 'Digite o código enviado para',
    complementoDescricao: Text(
      _emailRecuperacao!,
      key: const ValueKey('email-redefinicao'),
    ),
    onVoltar: carregando ? null : _voltarParaLogin,
    child: AbsorbPointer(
      absorbing: carregando,
      child: Column(
        key: const ValueKey('formulario-redefinicao'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _campoRedefinicao(
            rotulo: 'Código de recuperação',
            hint: '000000',
            controller: codigoController,
            codigo: true,
          ),
          const SizedBox(height: 18),
          _campoRedefinicao(
            rotulo: 'Nova senha',
            hint: 'Nova senha',
            controller: senhaController,
          ),
          const SizedBox(height: 8),
          const Text(
            'Pelo menos 8 caracteres, com letras e números.',
            style: TextStyle(color: Color(0xFF666879), fontSize: 13),
          ),
          const SizedBox(height: 18),
          _campoRedefinicao(
            rotulo: 'Confirmar nova senha',
            hint: 'Confirmar nova senha',
            controller: confirmarSenhaController,
            confirmacao: true,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const ValueKey('salvar-nova-senha'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(
                alpha: 0.65,
              ),
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
            onPressed: carregando ? null : redefinirSenha,
            child: Text(
              carregando ? 'SALVANDO...' : 'SALVAR NOVA SENHA',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: carregando ? null : solicitarCodigo,
            child: const Text('Reenviar código', textAlign: TextAlign.center),
          ),
        ],
      ),
    ),
  );

  Widget _campoRedefinicao({
    required String rotulo,
    required String hint,
    required TextEditingController controller,
    bool codigo = false,
    bool confirmacao = false,
  }) {
    final oculta = confirmacao ? _confirmacaoOculta : _novaSenhaOculta;
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
          key: ValueKey(
            codigo
                ? 'codigo-recuperacao'
                : confirmacao
                ? 'confirmar-nova-senha'
                : 'nova-senha-recuperacao',
          ),
          controller: controller,
          enabled: !carregando,
          obscureText: !codigo && oculta,
          keyboardType: codigo
              ? TextInputType.number
              : TextInputType.visiblePassword,
          textInputAction: confirmacao
              ? TextInputAction.done
              : TextInputAction.next,
          autofillHints: [
            codigo ? AutofillHints.oneTimeCode : AutofillHints.newPassword,
          ],
          autocorrect: false,
          enableSuggestions: false,
          textAlign: codigo ? TextAlign.center : TextAlign.start,
          maxLength: codigo ? 6 : null,
          inputFormatters: codigo
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          onSubmitted: confirmacao ? (_) => redefinirSenha() : null,
          style: TextStyle(color: AppColors.text, fontSize: codigo ? 24 : 16),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: const TextStyle(color: Color(0xFF727587)),
            constraints: BoxConstraints(minHeight: codigo ? 64 : 56),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: Icon(
              codigo ? Icons.mail_outline_rounded : Icons.lock_outline_rounded,
              color: const Color(0xFF666879),
            ),
            suffixIcon: codigo
                ? null
                : IconButton(
                    tooltip: oculta ? 'Mostrar senha' : 'Ocultar senha',
                    onPressed: carregando
                        ? null
                        : () => setState(() {
                            if (confirmacao) {
                              _confirmacaoOculta = !_confirmacaoOculta;
                            } else {
                              _novaSenhaOculta = !_novaSenhaOculta;
                            }
                          }),
                    icon: Icon(
                      oculta
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF666879),
                    ),
                  ),
            filled: true,
            fillColor: const Color(0xFFF6F6F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
