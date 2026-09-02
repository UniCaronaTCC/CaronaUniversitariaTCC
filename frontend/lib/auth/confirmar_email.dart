import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../services/email_verificacao_service.dart';
import '../widgets/auth_widgets.dart';
import 'login.dart';

class ConfirmarEmailTela extends StatefulWidget {
  final String email;

  const ConfirmarEmailTela({
    super.key,
    required this.email,
  });

  @override
  State<ConfirmarEmailTela> createState() => _ConfirmarEmailTelaState();
}

class _ConfirmarEmailTelaState extends State<ConfirmarEmailTela> {
  final codigoController = TextEditingController();

  Timer? timer;
  int segundos = 60;
  bool confirmando = false;
  bool reenviando = false;

  @override
  void initState() {
    super.initState();
    iniciarContagem();
  }

  void iniciarContagem() {
    timer?.cancel();
    segundos = 60;

    timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted) return;

        if (segundos <= 1) {
          timer?.cancel();
          setState(() => segundos = 0);
        } else {
          setState(() => segundos--);
        }
      },
    );
  }

  Future<void> confirmar() async {
    final codigo = codigoController.text.trim();

    if (!RegExp(r'^\d{8}$').hasMatch(codigo)) {
      mostrarMensagem('Informe o código de 8 dígitos');
      return;
    }

    setState(() => confirmando = true);

    final resultado = await EmailVerificacaoService.confirmarEmail(
      widget.email,
      codigo,
    );

    if (!mounted) return;

    setState(() => confirmando = false);

    if (resultado['sucesso'] == true) {
      mostrarMensagem(
        resultado['mensagem']?.toString() ??
            'E-mail confirmado com sucesso',
      );

      irParaLogin();
      return;
    }

    mostrarMensagem(
      resultado['mensagem']?.toString() ??
          'Não foi possível confirmar o e-mail',
    );
  }

  Future<void> reenviar() async {
    if (segundos > 0 || reenviando) return;

    setState(() => reenviando = true);

    final resultado = await EmailVerificacaoService.reenviarCodigo(
      widget.email,
    );

    if (!mounted) return;

    setState(() => reenviando = false);

    mostrarMensagem(
      resultado['mensagem']?.toString() ??
          'Não foi possível reenviar o código',
    );

    if (resultado['sucesso'] == true) {
      codigoController.clear();
      iniciarContagem();
    }
  }

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
      ),
    );
  }

  void irParaLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginTela(),
      ),
          (_) => false,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AuthCard(
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: Colors.white,
                  size: 46,
                ),
                const SizedBox(height: 14),
                const Text(
                  'CONFIRME SEU E-MAIL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enviamos um código de 8 dígitos para\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: codigoController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onSubmitted: (_) {
                    if (!confirmando) {
                      confirmar();
                    }
                  },
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '00000000',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                AuthBotaoPrincipal(
                  texto: confirmando
                      ? 'CONFIRMANDO...'
                      : 'CONFIRMAR E-MAIL',
                  onPressed: confirmando ? null : confirmar,
                ),
                const SizedBox(height: 16),
                if (segundos > 0)
                  Text(
                    'Reenviar código em ${segundos}s',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  )
                else
                  TextButton(
                    onPressed: reenviando ? null : reenviar,
                    child: Text(
                      reenviando
                          ? 'REENVIANDO...'
                          : 'REENVIAR CÓDIGO',
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed:
                  confirmando || reenviando ? null : irParaLogin,
                  child: const Text(
                    'Voltar para o login',
                    style: TextStyle(
                      color: Colors.white70,
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
