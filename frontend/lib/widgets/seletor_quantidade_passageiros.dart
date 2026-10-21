import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class SeletorQuantidadePassageiros extends StatelessWidget {
  final TextEditingController controller;
  final int? passageirosAceitos;

  const SeletorQuantidadePassageiros({
    super.key,
    required this.controller,
    this.passageirosAceitos,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, valor, _) {
        final quantidade = int.tryParse(valor.text);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    passageirosAceitos == null
                        ? 'Quantidade de passageiros'
                        : 'Capacidade de passageiros',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  for (var valor = 1; valor <= 4; valor++)
                    ButtonSegment(
                      value: valor,
                      label: Text('$valor'),
                      enabled: valor >= (passageirosAceitos ?? 0),
                    ),
                ],
                selected:
                    quantidade != null && quantidade >= 1 && quantidade <= 4
                    ? {quantidade}
                    : <int>{},
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                onSelectionChanged: (selecionados) {
                  if (selecionados.isNotEmpty) {
                    controller.text = selecionados.first.toString();
                  }
                },
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sem contar o motorista.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            if (passageirosAceitos != null && quantidade != null)
              Text(
                '$passageirosAceitos ${passageirosAceitos == 1 ? 'passageiro aceito' : 'passageiros aceitos'} · ${quantidade - passageirosAceitos!} ${quantidade - passageirosAceitos! == 1 ? 'vaga livre' : 'vagas livres'}',
              ),
          ],
        );
      },
    );
  }
}
