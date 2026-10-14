import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../home/notificacoes.dart';
import '../services/auth_service.dart';
import '../services/mensagem_service.dart';
import '../services/notificacao_service.dart';

class SinoNotificacoes extends StatefulWidget {
  final NotificacaoService service;
  const SinoNotificacoes({
    super.key,
    this.service = const NotificacaoService(),
  });
  @override
  State<SinoNotificacoes> createState() => _SinoNotificacoesState();
}

class _SinoNotificacoesState extends State<SinoNotificacoes>
    with WidgetsBindingObserver {
  Timer? timer;
  int total = 0;
  int geracao = 0;
  bool consultando = false;
  bool abrindo = false;
  bool emPrimeiroPlano = true;
  late final Object? idUsuario;

  @override
  void initState() {
    super.initState();
    idUsuario = AuthService.usuarioLogado?['id'];
    WidgetsBinding.instance.addObserver(this);
    MensagemService.versaoNotificacoes.addListener(atualizar);
    atualizar();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => atualizar());
  }

  @override
  void dispose() {
    geracao++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    MensagemService.versaoNotificacoes.removeListener(atualizar);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    emPrimeiroPlano = state == AppLifecycleState.resumed;
    if (emPrimeiroPlano) atualizar();
  }

  void atualizar() => unawaited(consultar());

  Future<void> consultar() async {
    if (consultando ||
        abrindo ||
        !emPrimeiroPlano ||
        idUsuario == null ||
        AuthService.usuarioLogado?['id'] != idUsuario ||
        !AuthService.estaLogado) {
      return;
    }
    consultando = true;
    final versao = geracao;
    try {
      final resposta = await widget.service.contar();
      if (mounted &&
          geracao == versao &&
          AuthService.usuarioLogado?['id'] == idUsuario &&
          resposta['sucesso'] == true &&
          resposta['dados'] is int) {
        setState(() => total = resposta['dados'] as int);
      }
    } catch (_) {
      return;
    } finally {
      consultando = false;
    }
  }

  Future<void> abrir() async {
    if (abrindo) return;
    abrindo = true;
    geracao++;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => NotificacoesTela(
            service: widget.service,
            onLeituraConfirmada: (restantes) {
              if (mounted) setState(() => total = restantes);
            },
          ),
        ),
      );
    } finally {
      abrindo = false;
      if (mounted) atualizar();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: Semantics(
      label: total == 0 ? 'Notificações' : 'Notificações: $total não lidas',
      child: IconButton(
        tooltip: 'Notificações',
        onPressed: abrir,
        icon: Badge(
          isLabelVisible: total > 0,
          backgroundColor: AppColors.primary,
          label: Text(total > 99 ? '99+' : '$total'),
          child: const Icon(
            Icons.notifications_none,
            size: 28,
            color: AppColors.primary,
          ),
        ),
      ),
    ),
  );
}
