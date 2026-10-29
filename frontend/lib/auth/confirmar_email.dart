import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../widgets/auth_secundario.dart';
import '../services/email_verificacao_service.dart';
import 'login.dart';

class ConfirmarEmailTela extends StatefulWidget {
  final String email;
  final Future<Map<String, dynamic>> Function(String email, String codigo)?
  confirmarCodigo;
  final Future<Map<String, dynamic>> Function(String email)? reenviarCodigo;
  final DateTime Function()? agora;

  const ConfirmarEmailTela({
    super.key,
    required this.email,
    this.confirmarCodigo,
    this.reenviarCodigo,
    this.agora,
  });

  @override
  State<ConfirmarEmailTela> createState() => _ConfirmarEmailTelaState();
}

class _ConfirmarEmailTelaState extends State<ConfirmarEmailTela>
    with WidgetsBindingObserver {
  final codigoController = TextEditingController();
  Timer? timer;
  late DateTime _liberarReenvioEm;
  int segundos = 60;
  bool confirmando = false;
  bool reenviando = false;
  String? _erroCodigo;

  bool get _ocupado => confirmando || reenviando;
  bool get _telaAtiva => mounted && ModalRoute.of(context)?.isCurrent == true;
  DateTime get _agora => (widget.agora ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    iniciarContagem();
  }

  void iniciarContagem() {
    timer?.cancel();
    _liberarReenvioEm = _agora.add(const Duration(seconds: 60));
    segundos = 60;
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _atualizarContagem(),
    );
  }

  void _atualizarContagem() {
    if (!mounted) return;
    final restantes =
        (_liberarReenvioEm.difference(_agora).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 60);
    if (restantes == 0) timer?.cancel();
    if (segundos != restantes) setState(() => segundos = restantes);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _atualizarContagem();
  }

  Future<void> confirmar() async {
    if (_ocupado || !_telaAtiva) return;
    final codigo = codigoController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(() => _erroCodigo = 'Informe o código de 6 dígitos');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      confirmando = true;
      _erroCodigo = null;
    });
    try {
      final resultado =
          await (widget.confirmarCodigo ??
              EmailVerificacaoService.confirmarEmail)(widget.email, codigo);
      if (!mounted || !_telaAtiva) return;
      if (resultado['sucesso'] == true) {
        mostrarMensagem(
          resultado['mensagem']?.toString() ?? 'E-mail confirmado com sucesso',
        );
        _abrirLogin();
      } else {
        setState(
          () => _erroCodigo =
              resultado['mensagem']?.toString() ??
              'Não foi possível confirmar o e-mail',
        );
      }
    } catch (_) {
      if (!mounted || !_telaAtiva) return;
      setState(
        () => _erroCodigo =
            'Não foi possível confirmar o e-mail. Tente novamente',
      );
    } finally {
      if (mounted) setState(() => confirmando = false);
    }
  }

  Future<void> reenviar() async {
    if (_ocupado || !_telaAtiva) return;
    _atualizarContagem();
    if (segundos > 0) return;
    FocusScope.of(context).unfocus();
    setState(() => reenviando = true);
    try {
      final resultado =
          await (widget.reenviarCodigo ??
              EmailVerificacaoService.reenviarCodigo)(widget.email);
      if (!mounted) return;
      if (resultado['sucesso'] == true) {
        codigoController.clear();
        _erroCodigo = null;
        iniciarContagem();
      }
      mostrarMensagem(
        resultado['mensagem']?.toString() ??
            (resultado['sucesso'] == true
                ? 'Novo código enviado'
                : 'Não foi possível reenviar o código'),
      );
    } catch (_) {
      if (!mounted) return;
      mostrarMensagem('Não foi possível reenviar o código. Tente novamente');
    } finally {
      if (mounted) setState(() => reenviando = false);
    }
  }

  void mostrarMensagem(String mensagem) {
    if (!_telaAtiva) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  void _voltarParaLogin() {
    if (_ocupado || !_telaAtiva) return;
    _abrirLogin();
  }

  void _abrirLogin() {
    if (!_telaAtiva) return;
    FocusScope.of(context).unfocus();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginTela()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TelaAuthSecundaria(
    identificador: 'confirmacao',
    titulo: 'Confirme seu e-mail',
    subtitulo: 'Enviamos um código de 6 dígitos para',
    onVoltar: _ocupado ? null : _voltarParaLogin,
    complementoDescricao: Text(
      widget.email,
      key: const ValueKey('email-confirmacao'),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Código de confirmação',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('codigo-confirmacao'),
          controller: codigoController,
          enabled: !_ocupado,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => confirmar(),
          onChanged: (_) {
            if (_erroCodigo != null) {
              setState(() => _erroCodigo = null);
            }
          },
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: const TextStyle(color: Color(0xFF727587)),
            constraints: const BoxConstraints(minHeight: 64),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: const Icon(
              Icons.mail_outline_rounded,
              color: Color(0xFF666879),
            ),
            filled: true,
            fillColor: const Color(0xFFF6F6F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _erroCodigo == null
                    ? const Color(0xFFD1D2DC)
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _erroCodigo == null
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.error,
                width: 2,
              ),
            ),
          ),
        ),
        if (_erroCodigo != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _erroCodigo!,
              key: const ValueKey('erro-confirmacao'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          key: const ValueKey('confirmar-email'),
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
          onPressed: _ocupado ? null : confirmar,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (confirmando) ...[
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
                  confirmando ? 'Confirmando...' : 'Confirmar e-mail',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Não recebeu o código?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF666879), fontSize: 14),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: const ValueKey('reenviar-confirmacao'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          onPressed: _ocupado || segundos > 0 ? null : reenviar,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                segundos > 0 ? Icons.schedule_outlined : Icons.refresh_rounded,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  reenviando
                      ? 'Reenviando...'
                      : segundos > 0
                      ? 'Reenviar código em ${segundos}s'
                      : 'Reenviar código',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          key: const ValueKey('login-confirmacao'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          onPressed: _ocupado ? null : _voltarParaLogin,
          child: const Text('Voltar para o login', textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}
