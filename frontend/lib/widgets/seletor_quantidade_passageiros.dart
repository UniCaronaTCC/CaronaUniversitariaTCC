import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class SeletorQuantidadePassageiros extends StatelessWidget {
  final TextEditingController controller;

  const SeletorQuantidadePassageiros({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, valor, _) {
        final quantidade = int.tryParse(valor.text);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Quantidade de passageiros',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
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
          ],
        );
      },
    );
  }
}
