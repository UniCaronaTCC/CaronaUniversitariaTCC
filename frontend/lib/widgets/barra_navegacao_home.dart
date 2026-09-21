import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/mensagem_service.dart';

class BarraNavegacaoHome extends StatefulWidget {
  final ValueChanged<int>? onTap;
  final int currentIndex;
  final int? totalMensagensNaoLidas;

  const BarraNavegacaoHome({
    super.key,
    this.onTap,
    this.currentIndex = 0,
    this.totalMensagensNaoLidas,
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
  }

  @override
  Widget build(BuildContext context) {
    final totalInformado = widget.totalMensagensNaoLidas;

    if (totalInformado != null) {
      return _barra(totalInformado);
    }

    return ValueListenableBuilder<int>(
      valueListenable: MensagemService.totalMensagensNaoLidas,
      builder: (_, total, _) => _barra(total),
    );
  }

  Widget _barra(int totalMensagensNaoLidas) {
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
          icon: Badge.count(
            count: totalMensagensNaoLidas,
            isLabelVisible: totalMensagensNaoLidas > 0,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.chat_bubble_outline),
          ),
          label: 'Chat',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.directions_car_outlined),
          label: 'Caronas',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    );
  }
}
