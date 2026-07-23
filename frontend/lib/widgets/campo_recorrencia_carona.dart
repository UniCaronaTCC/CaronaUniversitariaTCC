import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class CampoRecorrenciaCarona extends StatelessWidget {
  final bool caronaRecorrente;
  final List<String> diasSelecionados;
  final ValueChanged<bool> onRecorrenciaChanged;
  final ValueChanged<String> onDiaSelecionado;

  const CampoRecorrenciaCarona({
    super.key,
    required this.caronaRecorrente,
    required this.diasSelecionados,
    required this.onRecorrenciaChanged,
    required this.onDiaSelecionado,
  });

  static const List<String> diasSemana = [
    'SEG',
    'TER',
    'QUA',
    'QUI',
    'SEX',
    'SAB',
    'DOM',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Carona recorrente',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text('Repetir esta carona em dias da semana'),
            value: caronaRecorrente,
            activeThumbColor: AppColors.primary,
            onChanged: onRecorrenciaChanged,
          ),
          if (caronaRecorrente) ...[
            const SizedBox(height: 12),
            const Text(
              'Dias da semana',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: diasSemana.map((dia) {
                final selecionado = diasSelecionados.contains(dia);

                return ChoiceChip(
                  label: Text(dia),
                  selected: selecionado,
                  selectedColor: AppColors.primary,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selecionado ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) {
                    onDiaSelecionado(dia);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
