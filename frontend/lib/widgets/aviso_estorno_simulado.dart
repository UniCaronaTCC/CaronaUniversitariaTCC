import 'package:flutter/material.dart';
import 'visual_buscaeu.dart';

class AvisoEstornoSimulado extends StatelessWidget {
  const AvisoEstornoSimulado({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 12),
    child: Text(
      'Pagamento: estorno simulado registrado. '
      'Não houve movimentação de dinheiro real.',
      style: VisualBuscaEu.descricao,
    ),
  );
}
