import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class StatusSolicitacao extends StatelessWidget {
  final String status;

  const StatusSolicitacao({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cor = switch (status) {
      'ACEITA' => Colors.green,
      'RECUSADA' => Colors.red,
      'EXPIRADA' => Colors.black54,
      _ => AppColors.primary,
    };

    return Text(
      status,
      style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }
}
