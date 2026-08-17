import 'package:flutter/material.dart';

Future<bool> confirmarCancelamento(
  BuildContext context, {
  required bool confirmada,
  required bool motorista,
}) async {
  final titulo = confirmada
      ? 'Cancelar carona confirmada?'
      : 'Cancelar pedido?';
  final mensagem = motorista
      ? 'A participação deste passageiro será cancelada e a vaga ficará livre.'
      : confirmada
      ? 'Sua participação será cancelada e a vaga voltará a ficar disponível.'
      : 'Seu pedido será cancelado.';

  final confirmou = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('VOLTAR'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('CONFIRMAR CANCELAMENTO'),
        ),
      ],
    ),
  );

  return confirmou == true;
}
