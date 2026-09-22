import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/mensagem_service.dart';
import '../services/solicitacao_service.dart';

class BarraNavegacaoHome extends StatefulWidget {
  final ValueChanged<int>? onTap;
  final int currentIndex;
  final int? totalMensagensNaoLidas;
  final int? totalSolicitacoesPendentes;

  const BarraNavegacaoHome({
    super.key,
    this.onTap,
    this.currentIndex = 0,
    this.totalMensagensNaoLidas,
    this.totalSolicitacoesPendentes,
  });

  @override
  State<BarraNavegacaoHome> createState() => _BarraNavegacaoHomeState();
}

class _BarraNavegacaoHomeState extends State<BarraNavegacaoHome> {
  @override
  void initState() {
    super.initState();

    if (widget.totalMensagensNaoLidas == null) {
      unawaited(MensagemService.iniciarContadorMensagensNaoLidas());
    }

    if (widget.totalSolicitacoesPendentes == null) {
      unawaited(SolicitacaoService.iniciarContadorSolicitacoesPendentes());
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMensagensInformado = widget.totalMensagensNaoLidas;
    final totalSolicitacoesInformado = widget.totalSolicitacoesPendentes;

    if (totalMensagensInformado != null && totalSolicitacoesInformado != null) {
      return _barra(totalMensagensInformado, totalSolicitacoesInformado);
    }

    return ValueListenableBuilder<int>(
      valueListenable: MensagemService.totalMensagensNaoLidas,
      builder: (_, totalMensagens, _) => ValueListenableBuilder<int>(
        valueListenable: SolicitacaoService.totalSolicitacoesPendentes,
        builder: (_, totalSolicitacoes, _) => _barra(
          totalMensagensInformado ?? totalMensagens,
          totalSolicitacoesInformado ?? totalSolicitacoes,
        ),
      ),
    );
  }

  Widget _barra(
    int totalMensagensNaoLidas,
    int totalSolicitacoesPendentes,
  ) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.black54,
      type: BottomNavigationBarType.fixed,
      onTap: widget.onTap,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Início',
        ),
        BottomNavigationBarItem(
          icon: _iconeComContador(
            icone: Icons.chat_bubble_outline,
            total: totalMensagensNaoLidas,
          ),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: _iconeComContador(
            icone: Icons.directions_car_outlined,
            total: totalSolicitacoesPendentes,
          ),
          label: 'Caronas',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    );
  }

  Widget _iconeComContador({required IconData icone, required int total}) {
    final widgetIcone = Icon(icone);

    if (total <= 0) {
      return widgetIcone;
    }

    return Badge.count(
      count: total,
      backgroundColor: AppColors.primary,
      child: widgetIcone,
    );
  }
}
