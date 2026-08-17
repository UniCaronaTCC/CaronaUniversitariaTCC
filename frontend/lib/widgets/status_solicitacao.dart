import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class StatusSolicitacao extends StatelessWidget {
  final String status;

  const StatusSolicitacao({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cancelada = status.startsWith('CANCELADA_');
    final cor = switch (status) {
      'ACEITA' => Colors.green,
      'RECUSADA' => Colors.red,
      'EXPIRADA' => Colors.black54,
      'FINALIZADA' => Colors.black54,
      _ when cancelada => Colors.black54,
      _ => AppColors.primary,
    };

    return Text(
      cancelada ? 'CANCELADA' : status,
      style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }
}
