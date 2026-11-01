import 'package:flutter/material.dart';

import 'visual_buscaeu.dart';

class StatusSolicitacao extends StatelessWidget {
  final String status;

  const StatusSolicitacao({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cancelada = status.startsWith('CANCELADA_');
    final cor = switch (status) {
      'ACEITA' => Colors.green,
      'CONFIRMADA' => Colors.green,
      'RECUSADA' => Colors.red,
      'EXPIRADA' => Colors.black54,
      'FINALIZADA' => Colors.black54,
      _ when cancelada => Colors.black54,
      'PENDENTE' => const Color(0xFF9A6100),
      _ => VisualBuscaEu.secundario,
    };

    return SeloBuscaEu(
      texto: status == 'ENCERRADA_POR_TEMPO'
          ? 'Encerrada automaticamente por tempo'
          : cancelada
          ? 'CANCELADA'
          : status,
      cor: cor,
    );
  }
}
