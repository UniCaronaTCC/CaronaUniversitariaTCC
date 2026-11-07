import 'package:flutter/material.dart';

Future<bool> confirmarCancelamentoCarona(BuildContext context) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancelar esta carona?'),
      content: const SingleChildScrollView(
        child: Text(
          'Todos os pedidos e participações serão cancelados, e os passageiros '
          'serão avisados. Os pagamentos confirmados terão o estorno simulado '
          'registrado, sem movimentação de dinheiro real.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('VOLTAR'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('CANCELAR CARONA'),
        ),
      ],
    ),
  );
  return confirmou == true;
}
